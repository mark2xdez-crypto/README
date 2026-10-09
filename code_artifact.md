# บทเรียนคอมพิวเตอร์ช่วยสอน (CAI): เทคโนโลยีความจริงเสริมเพื่อการศึกษา
### รายวิชา ED1024 นวัตกรรมและเทคโนโลยีสารสนเทศทางการศึกษา

ระบบบทเรียนคอมพิวเตอร์ช่วยสอนบนเว็บ (Web-based CAI Courseware) พัฒนาขึ้นด้วยสถาปัตยกรรม Single-page Application ร่วมกับ Cloud Backend ของ Supabase เพื่อส่งเสริมสมรรถนะการออกแบบและสร้างสื่อนวัตกรรม WebAR ขั้นพื้นฐานตามหลักวิชาการสำหรับนักศึกษาวิชาชีพครู

---

## 📁 โครงสร้างไฟล์ในโปรเจกต์

| ชื่อไฟล์ | ชนิด | คำอธิบาย |
|---|---|---|
| `courseware.html` | Frontend Application | แอปพลิเคชันหน้าเดียว (HTML/CSS/JS) บรรจุเนื้อหา 5 หน่วย, แบบทดสอบคู่ขนาน A/B, ตัวแสดงผล WebAR `<model-viewer>` และแดชบอร์ดผู้เรียน/ผู้สอน |
| `setup.sql` | Database Script | สคริปต์ PostgreSQL สำหรับรันบน Supabase SQL Editor (ตาราง, Views, RLS, Storage Buckets, Triggers) |
| `documentation.md` | Academic & Technical Docs | ข้อสมมติระบบ, คู่มือการติดตั้ง 8 ขั้นตอน, แบบทดสอบระบบ 15 ข้อ, รายการตรวจสอบตนเอง และการอ้างอิงวิชาการ |
| `README.md` | Project Overview | ภาพรวมโปรเจกต์ สถาปัตยกรรม และคำแนะนำการเริ่มต้นใช้งานฉบับย่อ |

---

## ✨ คุณสมบัติเด่นของระบบ

### 1. ฝั่งผู้เรียน (Student Portal)
- **การเข้าสู่ระบบแบบอัตโนมัติ:** ใช้รหัสนักศึกษา 11 หลัก และรหัสผ่านที่กำหนดเอง ระบบตรวจสอบสิทธิ์กับฐานข้อมูลก่อนอนุญาตให้เข้าใช้งาน
- **บทเรียน 5 หน่วยการเรียนรู้:** มีคำถามแทรกวัดความเข้าใจแบบโต้ตอบ (Formative Assessment) ที่ต้องตอบถูกเพื่อปลดล็อกเนื้อหาถัดไป
- **แบบทดสอบคู่ขนาน (Parallel Tests):** สลับชุดข้อสอบ A และ B อัตโนมัติระหว่าง Pre-test และ Post-test ตามเลขท้ายรหัสนักศึกษา (คู่/คี่) เพื่อลดผลกระทบจากการจำข้อสอบ
- **วิเคราะห์ผลสัมฤทธิ์ทางการเรียน:** คำนวณและแสดงผลอัตราการเรียนรู้ Normalized Gain ($\langle g \rangle$) ตามแนวคิดของ Hake (1998) พร้อมเฉลยละเอียดหลังเรียน
- **ฝึกปฏิบัติ WebAR & ส่งงาน:** จำลองและทดสอบโมเดล 3 มิติบนเว็บ พร้อมฟอร์มส่งงานปฏิบัติทั้งรูปแบบ URL ลิงก์ และไฟล์แนบ (PNG, JPG, PDF, MP4)
- **จัดการโปรไฟล์:** อัปโหลดรูปภาพโปรไฟล์ พร้อมระบบย่อขนาดภาพอัตโนมัติในเบราว์เซอร์ก่อนบันทึกเข้า Private Storage

### 2. ฝั่งผู้สอน (Instructor Dashboard)
- **แดชบอร์ดผลการเรียนรายบุคคล:** ตรวจสอบความก้าวหน้าการเรียนทั้ง 5 หน่วย, คะแนน Pre-test, Post-test และ Normalized Gain
- **ตรวจและประเมินงานปฏิบัติ:** ให้คะแนนผลงาน AR (เต็ม 100 คะแนน) และบันทึกข้อเสนอแนะสะท้อนกลับ (Feedback) ไปยังผู้เรียน
- **คลังสื่อการสอนเพิ่มเติม:** อัปโหลดเอกสารประกอบการบรรยาย (PDF, PPTX, DOCX) และลิงก์วิดีโอเสริม
- **ส่งออกข้อมูล (Export CSV):** ส่งออกผลคะแนนและผลการเรียนทั้งหมดเป็นไฟล์ CSV รองรับ UTF-8 BOM สำหรับเปิดใน Microsoft Excel ภาษาไทยได้ทันที

---

## 🔒 มาตรการความปลอดภัย (Security & Integrity)

- **Row Level Security (RLS):** เปิดใช้งาน RLS บนทุกตาราง ผู้เรียนอ่านและแก้ไขได้เฉพาะข้อมูลตนเอง ผู้สอนเข้าถึงข้อมูลสรุปผ่าน `results` View (`security_invoker = true`)
- **การป้องกันการแก้ไขคะแนน:** มี Database Trigger `trg_protect_submission_grading` บล็อกไม่ให้ผู้เรียนแก้ไขคะแนนหรือข้อเสนอแนะของตนเองโดยเด็ดขาด
- **Private Storage:** ใช้ Signed URL ที่มีอายุจำกัดในการเปิดดูรูปถ่าย งานที่ส่ง และเอกสารประกอบการสอน
- **การป้องกัน XSS & Injections:** Escape ข้อมูลตัวอักษรทุกจุดก่อนเรนเดอร์ลงใน DOM และตรวจสอบ URL ให้ขึ้นต้นด้วย `http://` หรือ `https://` เท่านั้น

---

## 🚀 ขั้นตอนการเริ่มต้นใช้งานฉบับย่อ (Quick Start)

1. **เตรียมฐานข้อมูล Supabase:**
   - สร้างโปรเจกต์ใหม่บน [Supabase](https://supabase.com)
   - ไปที่ **Authentication** > **Providers** > **Email** แล้วปิดสวิตช์ **Confirm email**
   - นำโค้ดทั้งหมดจาก `setup.sql` ไปวางและกด **Run** ในเมนู **SQL Editor**
2. **สร้างบัญชีผู้สอน:**
   - สร้างบัญชีอีเมลผู้สอนใน **Authentication** > **Users**
   - รันคำสั่งเพิ่มสิทธิ์ใน SQL Editor:
     ```sql
     insert into public.teachers (user_id)
     select id from auth.users where email = 'your-teacher-email@example.com'
     on conflict do nothing;
     ```
3. **กำหนดค่าเชื่อมต่อในหน้าเว็บ:**
   - เปิดไฟล์ `courseware.html` ด้วย Text Editor
   - แก้ไขบรรทัดที่กำหนดค่า URL และ Key ให้ตรงกับโปรเจกต์ของคุณ:
     ```javascript
     const SUPABASE_URL = "https://YOUR_PROJECT_ID.supabase.co";
     const SUPABASE_ANON_KEY = "YOUR_ANON_KEY";
     ```
4. **เปิดใช้งาน:**
   - ดับเบิลคลิกเปิดไฟล์ `courseware.html` บนเว็บเบราว์เซอร์สมัยใหม่ (Google Chrome, Microsoft Edge, Safari) หรือโฮสต์บน Web Server เพื่อเริ่มจัดการเรียนการสอน

---

## 📚 เอกสารอ้างอิงทางวิชาการ

- **Azuma, R. T. (1997).** *A Survey of Augmented Reality.* Presence: Teleoperators and Virtual Environments.
- **Milgram, P., & Kishino, F. (1994).** *A Taxonomy of Mixed Reality Visual Displays.* IEICE Transactions on Information and Systems.
- **Mayer, R. E. (2009).** *Multimedia Learning.* Cambridge University Press.
- **Rovinelli, R. J., & Hambleton, R. K. (1977).** *On the use of content specialists in the assessment of criterion-referenced test item validity.*
- **Hake, R. R. (1998).** *Interactive-engagement versus traditional methods: A six-thousand-student survey of mechanics test data for introductory physics courses.* American Journal of Physics.