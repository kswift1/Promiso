use crate::errors::AppError;
use crate::services::gemini_client;

/// Gemini 응답에서 첫 번째 이모지 추출
///
/// 유니코드 이모지(ZWJ sequence 포함) 범위에서 첫 이모지를 반환한다.
/// 이모지가 없으면 "📅"을 반환한다.
pub fn extract_emoji_from_response(text: &str) -> String {
    // 이모지 여부 판별 함수
    // 이모지는 다음 범위를 포함한다:
    //   U+00A9, U+00AE (©, ®)
    //   U+2000..U+3300 (기호, 화살표, 기술 기호 등)
    //   U+1F000..U+1FFFF (이모지 주 블록)
    //   U+FE00..U+FE0F (변이 선택자)
    //   U+1F1E0..U+1F1FF (지역 표시 기호)
    fn is_emoji_char(c: char) -> bool {
        let cp = c as u32;
        matches!(cp,
            0x00A9        // ©
            | 0x00AE      // ®
            | 0x203C      // ‼
            | 0x2049      // ⁉
            | 0x20E3      // combining enclosing keycap
            | 0x2122      // ™
            | 0x2139      // ℹ
            | 0x2194..=0x2199
            | 0x21A9..=0x21AA
            | 0x231A..=0x231B
            | 0x2328
            | 0x23CF
            | 0x23E9..=0x23F3
            | 0x23F8..=0x23FA
            | 0x24C2
            | 0x25AA..=0x25AB
            | 0x25B6
            | 0x25C0
            | 0x25FB..=0x25FE
            | 0x2600..=0x2604
            | 0x260E
            | 0x2611
            | 0x2614..=0x2615
            | 0x2618
            | 0x261D
            | 0x2620
            | 0x2622..=0x2623
            | 0x2626
            | 0x262A
            | 0x262E..=0x262F
            | 0x2638..=0x263A
            | 0x2640
            | 0x2642
            | 0x2648..=0x2653
            | 0x265F..=0x2660
            | 0x2663
            | 0x2665..=0x2666
            | 0x2668
            | 0x267B
            | 0x267E..=0x267F
            | 0x2692..=0x2697
            | 0x2699
            | 0x269B..=0x269C
            | 0x26A0..=0x26A1
            | 0x26A7
            | 0x26AA..=0x26AB
            | 0x26B0..=0x26B1
            | 0x26BD..=0x26BE
            | 0x26C4..=0x26C5
            | 0x26CE..=0x26CF
            | 0x26D1
            | 0x26D3..=0x26D4
            | 0x26E9..=0x26EA
            | 0x26F0..=0x26F5
            | 0x26F7..=0x26FA
            | 0x26FD
            | 0x2702
            | 0x2705
            | 0x2708..=0x270D
            | 0x270F
            | 0x2712
            | 0x2714
            | 0x2716
            | 0x271D
            | 0x2721
            | 0x2728
            | 0x2733..=0x2734
            | 0x2744
            | 0x2747
            | 0x274C
            | 0x274E
            | 0x2753..=0x2755
            | 0x2757
            | 0x2763..=0x2764
            | 0x2795..=0x2797
            | 0x27A1
            | 0x27B0
            | 0x27BF
            | 0x2934..=0x2935
            | 0x2B05..=0x2B07
            | 0x2B1B..=0x2B1C
            | 0x2B50
            | 0x2B55
            | 0x3030
            | 0x303D
            | 0x3297
            | 0x3299
            | 0xFE00..=0xFE0F  // variation selectors
            | 0x1F000..=0x1FFFF // main emoji block (Mahjong, playing cards, misc symbols, transport, etc.)
            | 0xE0020..=0xE007F // tags
            | 0xE0100..=0xE01EF // variation selectors supplement
        )
    }

    // ZWJ (U+200D) 를 포함하는 compound emoji 지원
    // 이모지 시작점을 찾아, 이어지는 ZWJ sequence 전체를 하나의 이모지로 수집
    let chars: Vec<char> = text.chars().collect();
    let n = chars.len();
    let mut i = 0;

    while i < n {
        let c = chars[i];
        if is_emoji_char(c) {
            // ZWJ sequence 수집: 이모지, ZWJ(U+200D), variation selector(FE0F), keycap(20E3) 등을 이어서 수집
            let start = i;
            let mut j = i + 1;
            while j < n {
                let next = chars[j];
                if next == '\u{200D}' // ZWJ
                    || next == '\u{FE0F}' // variation selector
                    || next == '\u{20E3}' // combining enclosing keycap
                    || (next >= '\u{E0020}' && next <= '\u{E007F}') // tags
                    || (next >= '\u{1F1E0}' && next <= '\u{1F1FF}') // regional indicator
                    || is_emoji_char(next)
                        && j > start
                        && (chars[j - 1] == '\u{200D}'
                            || chars[j - 1] == '\u{FE0F}'
                            || chars[j - 1] == '\u{20E3}')
                {
                    j += 1;
                } else {
                    break;
                }
            }

            let emoji: String = chars[start..j].iter().collect();
            return emoji;
        }
        i += 1;
    }

    "📅".to_string()
}

/// Gemini 2.0 Flash로 이모지 생성, 실패 시 "📅" 반환
pub async fn generate_emoji(title: &str, api_key: &str) -> Result<String, AppError> {
    let prompt = format!("이 제목에 어울리는 이모지 1개만 반환: {title}");
    match gemini_client::call_gemini(&prompt, api_key).await {
        Ok(text) => Ok(extract_emoji_from_response(&text)),
        Err(()) => Ok("📅".to_string()),
    }
}
