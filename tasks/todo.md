# gomi_pic MVP 체크리스트

## 구현
- [x] Flutter 프로젝트 스캐폴딩 (`flutter create`)
- [x] `.gitignore`에 `.env` 추가
- [x] `.env` 템플릿 생성 (`GEMINI_API_KEY`)
- [x] `tasks/todo.md`, `tasks/lessons.md` 생성
- [x] `pubspec.yaml` 의존성 (camera, geolocator, geocoding, google_generative_ai, http, flutter_dotenv, shared_preferences, permission_handler, intl, uuid, flutter_localizations)
- [x] `AndroidManifest.xml` 권한 (CAMERA, ACCESS_FINE/COARSE_LOCATION, INTERNET)
- [x] `SafeScaffold` 공통 위젯 (시스템 네비바 겹침 방지)
- [x] 모델: `Classification`, `HistoryEntry`
- [x] `location_service.dart` (geolocator + geocoding → 구/시)
- [x] `gemini_service.dart` (Gemini 1.5 Flash REST + Google Search grounding + JSON 파싱)
- [x] `history_service.dart` (shared_preferences)
- [x] `home_screen.dart` (촬영 버튼 + 최근 기록)
- [x] `camera_screen.dart` (프리뷰 + 셔터 + AI 판정 로딩)
- [x] `result_screen.dart` (분류 결과 + 배출 규칙)
- [x] `main.dart` (dotenv 초기화 + 일본어 로케일 + MaterialApp)

## 검증
- [x] `flutter analyze` 무경고 (No issues found)
- [x] `flutter test` 통과 (2/2)
- [x] `flutter build apk --debug` 성공 (APK 생성)
- [ ] **사용자 수동 검증 필요**: 실기기/에뮬레이터 E2E
  - [ ] `.env` 파일에 실제 `GEMINI_API_KEY` 입력
  - [ ] 권한 다이얼로그(위치/카메라) 허용 후 홈 표시
  - [ ] 위치가 "渋谷区" 등 일본 구 단위로 표시되는지
  - [ ] 페트병 촬영 → "資源ごみ / ペットボトル" 3초 내 분류
  - [ ] 깨진 도자기 촬영 → "不燃ごみ" + 구체 배출법
  - [ ] 홈 복귀 시 최근 기록 갱신
  - [ ] 앱 재실행 시 기록 영속성
  - [ ] 시스템 네비게이션 바 겹침 없음 (육안 확인)

## 후속 (MVP 제외)
- [ ] 지모티 0엔 나눔 연동
- [ ] 대형쓰레기 자동 예약 (Operator)
- [ ] 웨어러블 알림
- [ ] iOS 빌드
- [ ] API 키 백엔드 프록시 (보안)

## Review

### 완료 상태 (2026-04-17)
- Flutter 3.38.7 / Dart 3.10.7 기반 Android 앱 스캐폴딩 및 MVP 핵심 루프 구현 완료
- 정적 분석·단위 테스트·디버그 APK 빌드 **전부 통과**
- 플랫폼별 설정: `minSdk = flutter.minSdkVersion` (Flutter 기본값, camera 패키지 요구 만족)
- Gemini 호출은 `google_generative_ai` Dart SDK 대신 REST 직호출 — 현행 SDK 버전은 `google_search_retrieval` 툴을 아직 노출하지 않기 때문

### 주의사항
- `.env`는 `.gitignore` 적용. 실행 전 `GEMINI_API_KEY` 값을 수기로 채워야 함
- API 키가 클라이언트에 내장되는 MVP 형태라 공개 배포 전 백엔드 프록시 필수
- Kotlin 증분 캐시 경고(pub 캐시 C: / 프로젝트 E: 드라이브 분리로 인한 relative path 이슈)는 빌드 산출물에 영향 없음

### 다음 단계
- 사용자가 실제 API 키를 `.env`에 넣고 `flutter run`으로 실기기 검증
- 문제 발생 시 `tasks/lessons.md`에 교정 내용 누적
