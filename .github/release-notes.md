> [!WARNING]
> **เวอร์ชันทดสอบ (alpha)** ยังอาจมีบัค ทดสอบแล้วเฉพาะ iQOO 15 (PD2505) บน OriginOS 6
>
> **Alpha build** — may still have bugs. Tested only on the iQOO 15 (PD2505), OriginOS 6. The app follows the device language (Thai / English). See the [English README](../../blob/main/README.en.md) for install steps.

## มีอะไรใหม่ / What's new

- **อัปเดตในแอป** เปิดแอปแล้วจะเช็กเวอร์ชันใหม่ให้เอง กด **อัปเดต** เพื่อดาวน์โหลดและติดตั้ง (ครั้งแรกต้องอนุญาต "ติดตั้งแอปที่ไม่รู้จัก") · **In-app updates**: the app checks for new releases and installs them through the system installer
- **ทดลอง:** แทรกเฟรมเปลี่ยนไปเขียน `gamecube_frame_interpolation_for_sr` (`1:1::48:144`) ซึ่ง GameCube ไม่เขียนทับตอนเข้าเกม · **Experimental:** frame generation now writes `gamecube_frame_interpolation_for_sr`

> [!IMPORTANT]
> ตัวช่วย (Helper) อัปเป็นเวอร์ชัน 2 หลังอัปเดตให้เปิด Shizuku แล้วกด **ตั้งค่าอัตโนมัติ** อีกครั้ง และควร **ปิดแทรกเฟรมในเวอร์ชันเก่าก่อนอัปเดต** · The helper was updated: run **Auto setup** again with Shizuku, and turn frame generation off in the old version before updating.

## ติดตั้ง

1. ติดตั้ง [Shizuku](https://shizuku.rikka.app/) แล้วกด Start ผ่าน Wireless debugging
2. ดาวน์โหลดไฟล์ `.apk` ด้านล่าง แล้วกดติดตั้ง
3. เปิดแอป → **ตั้งค่าอัตโนมัติ** → อนุญาต Shizuku
4. เปิดสวิตช์ **Usage access** ให้ Origin Tweaks (ใช้กับ Profile รายเกม)
5. เพิ่มปุ่ม **แทรกเฟรม** ลง panel

ถ้าเคยติดตั้งเวอร์ชันที่ build เอง (debug) ไว้ ให้ถอนทั้ง **Origin Tweaks** และ **Origin Tweaks Helper** ก่อน เพราะลายเซ็นต่างกัน

## อยากให้ช่วยทดสอบ

- [ ] ตั้งค่าอัตโนมัติผ่านครบไหม
- [ ] เปิด 144 FPS แล้วในเกมขึ้น 144 จริงไหม (ดูจาก FPS meter ของ Ultra Game Mode)
- [ ] 90 / 120 FPS ใช้ได้ไหม (ยังไม่เคยทดสอบ)
- [ ] ปุ่มใน panel แสดงสถานะถูกไหม
- [ ] Profile รายเกม: เข้าเกมแล้วเปิดเอง ออกเกมแล้วคืนค่าไหม
- [ ] ปิดแล้วค่าต่างๆ กลับเป็นเหมือนเดิมไหม
- [ ] รุ่นอื่นนอกจาก iQOO 15 ใช้ได้ไหม

เจอปัญหาแจ้งได้ที่ [Issues](../../issues/new/choose) พร้อมบอกรุ่นเครื่องและเวอร์ชัน OriginOS

ตรวจสอบไฟล์ได้ด้วยไฟล์ `.sha256` ที่แนบมา
