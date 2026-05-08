# Lessons

세션 중 사용자 교정 또는 검증된 판단이 생기면 여기에 누적.
각 항목: 규칙 → **Why** (근거/이전 사건) → **How to apply** (언제 적용).

---

## `Scaffold.bottomNavigationBar`에 `Center`/`Align`을 직접 child로 쓰면 안 된다

**Why:** Scaffold는 bottomNavigationBar 슬롯을 loose constraints(min=0, max=화면 높이)로 측정한다. `Center`/`Align`은 widthFactor/heightFactor가 null일 때 loose constraints에서 max 크기로 확장되므로 **bottomNavigationBar가 화면 전체 높이를 차지**하고, 결과적으로 AppBar+body가 0px로 눌려 화면이 통째로 검정이 되는 현상이 발생한다. gomi_pic 카메라 화면에서 "AppBar·카메라 프리뷰가 사라지고 촬영 버튼만 화면 한가운데 떠 있다"로 관측된 실제 버그.

**How to apply:**
- 중앙 정렬이 필요하면 `Row(mainAxisAlignment: MainAxisAlignment.center, children: [...])` 또는 `Column`을 쓴다 (Row/Column은 children의 intrinsic size로 축소).
- 또는 `Align`에 `heightFactor: 1.0` 명시, 또는 바깥을 `SizedBox(height: ...)`로 감싼다.
- 빠른 체크: bottomNavigationBar에 `Center`가 보이면 의심한다.

---

## Flutter 로딩 오버레이는 `Positioned.fill`로 명시적으로 전체 화면을 덮어야 한다

**Why:** `Stack` 안의 non-positioned `Container(color: ..., alignment: center)`는 child의 intrinsic size로만 커지기 때문에, 스피너+텍스트 주위에만 작은 반투명 사각형이 생긴다. 카메라 프리뷰가 블랙으로 얼어붙은 상황(takePicture 중)과 겹치면 사용자는 "그냥 까만 화면에 비활성 버튼만 있다"고 느낀다.

**How to apply:** 로딩 overlay는 반드시 `Positioned.fill(child: Container(...))` 또는 `Stack(fit: StackFit.expand)`로 감싸고, 스피너·설명 문구·예상 소요시간을 크게 표시한다.

---

## CameraController는 ResolutionPreset.medium을 기본으로

**Why:** `high`/`max`는 일부 저가/중가 Android 기기에서 initialize가 무한 대기하거나 preview가 검정으로 시작하는 사례가 있다. medium이 호환성과 품질 사이의 안전한 기본.

**How to apply:** 촬영 품질이 꼭 필요한 feature(문서 OCR 등)가 아니면 medium으로 시작. 문제가 생기면 low로 fallback.

---

## 카메라/위치처럼 런타임 권한이 필요한 기능은 permission_handler로 명시적으로 요청

**Why:** `camera` 플러그인의 `initialize()`가 Android 13+ 등 환경에 따라 권한 다이얼로그를 띄우지 않고 바로 예외를 던지는 경우가 있다. 사용자 입장에서는 "카메라 권한 거부" 상태가 뭔지 모른 채 검은 화면만 본다.

**How to apply:** camera 초기화 전에 `Permission.camera.request()`를 호출하고, 거부됐을 때는 `openAppSettings()` 링크를 포함한 명확한 에러 화면을 보여준다.
