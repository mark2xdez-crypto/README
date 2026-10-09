-- ==============================================================================
-- CAI Web Courseware Database Setup Script (Fixed & Verified)
-- Course: ED1024 Augmented Reality for Education
-- Engine: Supabase (PostgreSQL with RLS and Storage Policies)
-- ==============================================================================

-- 1. Create Application Tables
-- ------------------------------------------------------------------------------

-- 1.1 Teachers table
create table if not exists public.teachers (
    user_id uuid primary key references auth.users(id) on delete cascade,
    created_at timestamptz default now()
);

-- 1.2 Students pre-registered roster table
create table if not exists public.students (
    id varchar(11) primary key,
    title text not null default 'นาย',
    first_name text not null,
    last_name text not null,
    section text not null default 'SEC01',
    user_id uuid unique references auth.users(id) on delete set null,
    photo_path text,
    created_at timestamptz default now()
);

-- 1.3 Pre/Post test attempts table (Only 1 attempt per kind)
create table if not exists public.attempts (
    id uuid default gen_random_uuid() primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    kind text not null check (kind in ('pre', 'post')),
    score integer not null check (score >= 0 and score <= 10),
    answers jsonb not null default '{}'::jsonb,
    created_at timestamptz default now(),
    unique(user_id, kind)
);

-- 1.4 Unit Progress table
create table if not exists public.progress (
    id uuid default gen_random_uuid() primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    unit integer not null check (unit between 1 and 5),
    done boolean not null default false,
    updated_at timestamptz default now(),
    unique(user_id, unit)
);

-- 1.5 Submissions table for practical AR task
-- Note: Foreign key to students(user_id) allows PostgREST nested resource expansion
create table if not exists public.submissions (
    id uuid default gen_random_uuid() primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    unit integer not null default 4,
    kind text not null check (kind in ('link', 'file')),
    url text,
    storage_path text,
    note text,
    score numeric check (score >= 0 and score <= 100),
    teacher_comment text,
    created_at timestamptz default now(),
    constraint fk_submissions_students foreign key (user_id) references public.students(user_id) on delete cascade
);

-- 1.6 Supplementary Materials table
create table if not exists public.materials (
    id uuid default gen_random_uuid() primary key,
    title text not null,
    kind text not null check (kind in ('file', 'link', 'video')),
    url text,
    storage_path text,
    file_name text,
    created_at timestamptz default now()
);

-- 2. Security Functions & Views
-- ------------------------------------------------------------------------------

-- Helper function: Check if current authenticated user is a teacher
create or replace function public.is_teacher()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.teachers where user_id = auth.uid()
  );
$$;

-- Security Invoker View for Teacher Dashboard (Fixed alias syntax)
create or replace view public.results
with (security_invoker = true)
as
select 
    s.id as student_id,
    s.title,
    s.first_name,
    s.last_name,
    s.section,
    s.user_id,
    s.photo_path,
    att_pre.score as pre_score,
    att_post.score as post_score,
    case 
        when att_pre.score is null or att_post.score is null then null
        when 10 - att_pre.score = 0 then 
            case when att_post.score >= att_pre.score then 1.00 else 0.00 end
        else round(((att_post.score - att_pre.score)::numeric / (10 - att_pre.score)::numeric), 2)
    end as normalized_gain,
    coalesce(prog.completed_units, 0) as completed_units,
    sub.submission_count,
    sub.latest_submission_score
from public.students s
left join public.attempts att_pre on s.user_id = att_pre.user_id and att_pre.kind = 'pre'
left join public.attempts att_post on s.user_id = att_post.user_id and att_post.kind = 'post'
left join (
    select user_id, count(*) filter (where done = true) as completed_units
    from public.progress
    group by user_id
) prog on s.user_id = prog.user_id
left join (
    select user_id, count(*) as submission_count, max(score) as latest_submission_score
    from public.submissions
    group by user_id
) sub on s.user_id = sub.user_id;

-- 3. Row Level Security (RLS) Configuration
-- ------------------------------------------------------------------------------

alter table public.teachers enable row level security;
alter table public.students enable row level security;
alter table public.attempts enable row level security;
alter table public.progress enable row level security;
alter table public.submissions enable row level security;
alter table public.materials enable row level security;

-- Revoke all permissions from anonymous users (Fixed syntax error)
revoke all on public.teachers from anon;
revoke all on public.students from anon;
revoke all on public.attempts from anon;
revoke all on public.progress from anon;
revoke all on public.submissions from anon;
revoke all on public.materials from anon;

-- Grant permissions to authenticated users
grant select, insert, update, delete on public.teachers to authenticated;
grant select, insert, update, delete on public.students to authenticated;
grant select, insert, update, delete on public.attempts to authenticated;
grant select, insert, update, delete on public.progress to authenticated;
grant select, insert, update, delete on public.submissions to authenticated;
grant select, insert, update, delete on public.materials to authenticated;
grant select on public.results to authenticated;

-- Policies: TEACHERS TABLE
drop policy if exists "teachers_select" on public.teachers;
create policy "teachers_select" on public.teachers
    for select to authenticated using (public.is_teacher() or auth.uid() = user_id);

-- Policies: STUDENTS TABLE
drop policy if exists "students_select" on public.students;
create policy "students_select" on public.students
    for select to authenticated using (public.is_teacher() or auth.uid() = user_id);

drop policy if exists "students_update_photo" on public.students;
create policy "students_update_photo" on public.students
    for update to authenticated
    using (public.is_teacher() or auth.uid() = user_id)
    with check (public.is_teacher() or auth.uid() = user_id);

-- Policies: ATTEMPTS TABLE
drop policy if exists "attempts_select" on public.attempts;
create policy "attempts_select" on public.attempts
    for select to authenticated using (public.is_teacher() or auth.uid() = user_id);

drop policy if exists "attempts_insert" on public.attempts;
create policy "attempts_insert" on public.attempts
    for insert to authenticated with check (auth.uid() = user_id);

-- Policies: PROGRESS TABLE
drop policy if exists "progress_select" on public.progress;
create policy "progress_select" on public.progress
    for select to authenticated using (public.is_teacher() or auth.uid() = user_id);

drop policy if exists "progress_upsert" on public.progress;
create policy "progress_upsert" on public.progress
    for all to authenticated
    using (public.is_teacher() or auth.uid() = user_id)
    with check (public.is_teacher() or auth.uid() = user_id);

-- Policies: SUBMISSIONS TABLE
drop policy if exists "submissions_select" on public.submissions;
create policy "submissions_select" on public.submissions
    for select to authenticated using (public.is_teacher() or auth.uid() = user_id);

drop policy if exists "submissions_insert" on public.submissions;
create policy "submissions_insert" on public.submissions
    for insert to authenticated with check (auth.uid() = user_id and score is null and teacher_comment is null);

drop policy if exists "submissions_update" on public.submissions;
create policy "submissions_update" on public.submissions
    for update to authenticated
    using (public.is_teacher() or auth.uid() = user_id)
    with check (public.is_teacher() or auth.uid() = user_id);

-- Policies: MATERIALS TABLE
drop policy if exists "materials_select" on public.materials;
create policy "materials_select" on public.materials
    for select to authenticated using (true);

drop policy if exists "materials_teacher_all" on public.materials;
create policy "materials_teacher_all" on public.materials
    for all to authenticated
    using (public.is_teacher())
    with check (public.is_teacher());

-- 4. Protection Trigger: Prevent Students from modifying scores
-- ------------------------------------------------------------------------------

create or replace function public.trg_check_submission_grading()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if not public.is_teacher() then
        if new.score is distinct from old.score or new.teacher_comment is distinct from old.teacher_comment then
            raise exception 'ไม่อนุญาตให้นักศึกษาแก้ไขคะแนนหรือข้อคิดเห็นของผู้สอน';
        end if;
        if new.user_id <> old.user_id then
            raise exception 'ไม่อนุญาตให้แก้ไขเจ้าของผลงาน';
        end if;
    end if;
    return new;
end;
$$;

drop trigger if exists trg_protect_submission_grading on public.submissions;
create trigger trg_protect_submission_grading
before update on public.submissions
for each row
execute function public.trg_check_submission_grading();

-- 5. Trigger: Auto-link and Validate Student Registration on auth.users
-- ------------------------------------------------------------------------------
create or replace function public.handle_new_user_signup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_student_id text;
    v_exists boolean;
    v_already_used boolean;
begin
    -- Check if email matches 11-digit pattern: e.g. 66011234001@cai.internal
    v_student_id := substring(new.email from '^([0-9]{11})@');
    
    if v_student_id is not null then
        -- Check if student ID exists in the pre-registered students roster
        select exists(select 1 from public.students where id = v_student_id) into v_exists;
        if not v_exists then
            raise exception 'รหัสนักศึกษา % ไม่มีในรายชื่อผู้มีสิทธิ์เรียนรายวิชานี้', v_student_id;
        end if;

        -- Check if student ID has already been claimed by another user account
        select exists(select 1 from public.students where id = v_student_id and user_id is not null and user_id <> new.id) into v_already_used;
        if v_already_used then
            raise exception 'รหัสนักศึกษา % มีการลงทะเบียนในระบบเรียบร้อยแล้ว', v_student_id;
        end if;

        -- Link the newly created auth user ID to the student record
        update public.students
        set user_id = new.id
        where id = v_student_id;
    end if;

    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user_signup();

-- 6. Supabase Storage Setup (Private Buckets & Policies)
-- ------------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
    ('photos', 'photos', false, 2097152, array['image/jpeg', 'image/png', 'image/webp']),
    ('submissions', 'submissions', false, 20971520, array['image/png', 'image/jpeg', 'application/pdf', 'video/mp4']),
    ('materials', 'materials', false, 52428800, array['application/pdf', 'application/vnd.ms-powerpoint', 'application/vnd.openxmlformats-officedocument.presentationml.presentation', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do update set
    public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Storage Policies for 'photos'
drop policy if exists "photos_owner_manage" on storage.objects;
create policy "photos_owner_manage" on storage.objects
    for all to authenticated
    using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text)
    with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "photos_read_teacher" on storage.objects;
create policy "photos_read_teacher" on storage.objects
    for select to authenticated
    using (bucket_id = 'photos' and (public.is_teacher() or (storage.foldername(name))[1] = auth.uid()::text));

-- Storage Policies for 'submissions'
drop policy if exists "submissions_owner_manage" on storage.objects;
create policy "submissions_owner_manage" on storage.objects
    for all to authenticated
    using (bucket_id = 'submissions' and (storage.foldername(name))[1] = auth.uid()::text)
    with check (bucket_id = 'submissions' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "submissions_read_teacher" on storage.objects;
create policy "submissions_read_teacher" on storage.objects
    for select to authenticated
    using (bucket_id = 'submissions' and (public.is_teacher() or (storage.foldername(name))[1] = auth.uid()::text));

-- Storage Policies for 'materials'
drop policy if exists "materials_read_all" on storage.objects;
create policy "materials_read_all" on storage.objects
    for select to authenticated
    using (bucket_id = 'materials');

drop policy if exists "materials_teacher_manage" on storage.objects;
create policy "materials_teacher_manage" on storage.objects
    for all to authenticated
    using (bucket_id = 'materials' and public.is_teacher())
    with check (bucket_id = 'materials' and public.is_teacher());

-- 7. Mock Data: 6 Pre-registered Students
-- ------------------------------------------------------------------------------
insert into public.students (id, title, first_name, last_name, section)
values
    ('66011234001', 'นาย', 'กิตติศักดิ์', 'เจริญสุข', 'SEC01'),
    ('66011234002', 'นางสาว', 'พรปวีณ์', 'สิทธิโชค', 'SEC01'),
    ('66011234003', 'นาย', 'ชลธี', 'ธาราสกุล', 'SEC01'),
    ('66011234004', 'นางสาว', 'มัลลิกา', 'เกียรติไพบูลย์', 'SEC01'),
    ('66011234005', 'นาย', 'ธนกฤต', 'วงศ์วิริยะ', 'SEC02'),
    ('66011234006', 'นางสาว', 'ศุภิสรา', 'รัตนมณี', 'SEC02')
on conflict (id) do nothing;

-- 8. Teacher Initialization Command (Template)
-- ------------------------------------------------------------------------------
-- insert into public.teachers (user_id)
-- select id from auth.users where email = 'teacher@institution.ac.th'
-- on conflict do nothing;