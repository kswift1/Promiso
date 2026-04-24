CREATE TABLE faqs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question    TEXT NOT NULL,
    answer      TEXT NOT NULL,
    category    TEXT NOT NULL DEFAULT '기타',
    sort_order  INT NOT NULL DEFAULT 999,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_faqs_active_order ON faqs (is_active, sort_order);

INSERT INTO faqs (question, answer, category, sort_order) VALUES
    (
        '알림이 오지 않아요',
        '설정 > 알림에서 알림 권한이 허용되어 있는지 확인해주세요. iOS 설정에서도 Promiso 앱 알림이 활성화되어 있어야 합니다. 배터리 절약 모드가 켜져 있으면 알림이 제한될 수 있어요.',
        '알림',
        1
    ),
    (
        '실시간 공유는 어떻게 하나요?',
        '약속 생성 시 설정한 시간에 맞춰 실시간 도착 현황이 자동으로 시작돼요. 약속 상세 화면에서 그룹원들의 도착 상태를 확인할 수 있어요.',
        '약속',
        2
    ),
    (
        '계정을 삭제하고 싶어요',
        '설정 > 프로필 > 탈퇴하기 에서 계정을 삭제할 수 있어요. 탈퇴 시 모든 데이터가 삭제되며 복구할 수 없으니 신중하게 결정해주세요.',
        '계정',
        1
    ),
    (
        '그룹은 어떻게 만들 수 있나요?',
        '그룹 화면에서 + 버튼을 탭해주세요. ''새 그룹 만들기''를 선택한 후 그룹 이름과 설명을 입력하고 멤버를 초대하면 그룹을 만들 수 있어요.',
        '그룹',
        1
    ),
    (
        '그룹에 친구를 초대하려면 어떻게 하나요?',
        '그룹 상세 화면에서 우측 상단의 멤버 아이콘을 탭해주세요. 초대 링크를 공유하면 친구가 그룹에 참여할 수 있어요.',
        '그룹',
        2
    ),
    (
        '약속 시간을 변경할 수 있나요?',
        '약속 상세 화면에서 수정 버튼을 탭하면 시간, 장소 등을 변경할 수 있습니다. 변경 시 그룹원들에게 알림이 발송됩니다.',
        '약속',
        1
    ),
    (
        '도착 시간은 자동으로 계산되나요?',
        '아니요. 참가자가 직접 입력하는 방식입니다.',
        '실시간현황',
        1
    ),
    (
        '실시간 공유는 언제 시작되나요?',
        '약속이 확정되고, 설정한 시간(기본 30분 전)이 되면 자동으로 시작됩니다. 모든 참가자가 도착하면 5분 후 자동 종료돼요.',
        '실시간현황',
        2
    ),
    (
        '앱을 종료해도 실시간 공유가 유지되나요?',
        '네. 잠금화면에서 앱과 독립적으로 동작합니다. 앱을 종료해도 확인하고 변경할 수 있어요.',
        '실시간현황',
        3
    ),
    (
        '모두 도착하면 어떻게 되나요?',
        '"모두 도착!" 알림이 전송되고, 5분 후 자동 종료됩니다. 가장 먼저 도착하면 🎉 첫 도착 알림도 받아요!',
        '실시간현황',
        4
    ),
    (
        '한번 끄면 다시 켤 수 있나요?',
        '현재는 같은 약속에 대해 재활성화할 수 없어요. 실수로 스와이프하지 않도록 주의해주세요.',
        '실시간현황',
        5
    );

ALTER TABLE app_config DROP COLUMN notion_faq_database_id;
