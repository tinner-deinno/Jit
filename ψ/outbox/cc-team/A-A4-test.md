<!-- cc-team deliverable
 group: A (TICKET-002: Thai Knowledge Routing Audit — produce test corpus, harness, and hardening proposals)
 member: A4 role=test model=zai-org/GLM-5.1
 finish_reason: length | tokens: {"prompt_tokens":153,"completion_tokens":6000,"total_tokens":6153,"prompt_tokens_details":{"cached_tokens":3,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":1937,"reasoning_tokens_estimated":true,"image_tokens":0},"cache_creation_input_tokens":0} | 119s
 generated: 2026-06-10T19:23:11.514Z -->
[
  {
    "id": "E01",
    "prompt": "ผมอยากได้ flight ไปกรุงเทพฯวันพรุ่งนี้ แบบ economy class แล้วก็รับ baggage ที่ carousel ไหนครับ",
    "category": "code-switching Thai-English",
    "expected_behavior": "ระบบต้องจดจำว่าเป็นภาษาไทยเป็นหลักและส่งไปยังเส้นทางที่รองรับคำผสมภาษาไทย-อังกฤษได้อย่างถูกต้อง โดยไม่ตัดคำภาษาอังกฤษทิ้ง"
  },
  {
    "id": "E02",
    "prompt": "ช่วย update database ให้หน่อยได้ไหม แล้วก็ run script ตัวใหม่ที่ backend เพื่อ sync data ข้ามา",
    "category": "code-switching Thai-English",
    "expected_behavior": "ระบบต้องประมวลผลคำผสมภาษาไทย-อังกฤษในบริบทเทคโนโลยีได้อย่างราบรื่น และจัดเส้นทางไปยังโมดูลที่เกี่ยวข้องกับ IT หรือการเขียนโปรแกรม"
  },
  {
    "id": "E03",
    "prompt": "Meeting บ่ายนี้ต้อง present หัวข้อ budget ของ project นะ อย่าลืม prepare slide ด้วย",
    "category": "code-switching Thai-English",
    "expected_behavior": "ระบบต้องรักษาบริบทของการป���ะชุมและงานออฟฟิศที่มีคำศัพท์ภาษาอังกฤษแ���รก และจัดเส้นทางไปยังประเภทการทำงานที่เหมาะสม"
  },
  {
    "id": "E04",
    "prompt": "สั่งของมา ๒๐๐ ชิ้น แต่ได้รับมาแค่ 150 ชิ้น ขาดอีก ๕๐ ชิ้น กรุณาตรวจสอบภายใน 24 ชั่วโมง",
    "category": "Thai numerals and Arabic numerals mixed",
    "expected_behavior": "ระบบต้องตีความตัวเลขไทยและอารบิกให้เป็นค่าตัวเลขที่เท่ากันได้ และไม่ต้องเกิดข้อผิดพลาดในการแปลงชนิดข้อมูล"
  },
  {
    "id": "E05",
    "prompt": "โปรโมชั่นปี ๒๕๖๗ ลดราคา 30% สำหรับสินค้า ๓ รายการแรก หรือซื้อครบ 1,500 บาทรับฟรีอีก ๑ ชิ้น",
    "category": "Thai numerals and Arabic numerals mixed",
    "expected_behavior": "ระบบต้องจัดการตัวเลขที่หลากหลายรูปแบบในประโยคเดียวกั���ได้ โดยคงความหมายของจำนวนเงินและส่วนลดไว้อย่างครบถ้วน"
  },
  {
    "id": "E06",
    "prompt": "สวัสดีวันจันทร์ 🌞🌞🌞 อยากกินข้าวผัด 🍤🍚 แต่ร้านปิด 😭😭😭 ใครช่วยส่งอาหารมาให้หน่อยได้ไหม 🛵🛵🛵🥺🥺🥺",
    "category": "emoji-heavy",
    "expected_behavior": "ระบบต้องกรองหรือละเว้นอิโมจิที่ซ้ำซ้อนเพื่อสกัดเนื้อหาหลักด้านการสั่งอาหาร และจัดเส้นทางไปยังบริการส่งอาหารหรือฝ่ายสนับสนุนลูกค้า"
  },
  {
    "id": "E07",
    "prompt": "🎉🎊🥳 ยินดีด้วยนะคะ! คุณได้รับรางวัลที่
