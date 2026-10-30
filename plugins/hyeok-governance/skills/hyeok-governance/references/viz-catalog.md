# 상황별 시각화 선택

시각화가 설명에 도움이 될 때만 읽는다. 질문 하나를 가장 잘 설명하는 스킬 하나를 고른 뒤,
그 스킬의 `SKILL.md`와 선택한 유형의 참고 파일만 읽는다. 실행 준비, 의존성, 검증 방법은
[설정 가이드](visualization-setup.md)를 필요할 때만 읽는다.
제공 서버의 Codex CLI 실행 기준은 [서버 CLI 안내](server-cli.md)를 따른다.

다른 스킬의 루트는 현재 세션의 스킬 목록에서 이름을 찾아, 제공된 `SKILL.md` 경로의
상위 디렉터리로 확인한다. 이 거버넌스 파일에서 형제 플러그인의 상대 위치를 추정하지 않는다.

사용자가 지정한 형식과 스킬, 기존 프로젝트의 구현 방식을 따른다. 평가 환경에서는
주최 측 지침이 우선이다. 이 목록에 도구가 있다고 현재 세션에서 호출 가능하거나 평가에서
허용된 것으로 간주하지 않는다. 단일 사실이나 단순 비교는 문장이나 표로 충분하다.

움직이는 데이터 차트, UI 모션, 명시적인 Three.js 작업으로 범위를 확장할 때는
[선별한 확장 후보](source-catalog.md#애니메이션과-3d-확장-후보)를 확인한다.
기본 도식에 애니메이션이나 3D를 자동으로 추가하지 않는다.

## 1. 결과물과 의미로 선택

| 보여줄 것 | 우선 선택 | 겹칠 때 판단 기준 |
|---|---|---|
| 실제 서비스, 인프라, 보안 경계, 배포 구성 | `archify / architecture` | 코드나 설정에서 확인한 구성요소와 연결을 보여줌 |
| 도구 실행 절차, API 요청과 응답, 실행 상태 전이 | `archify / workflow`, `sequence`, `lifecycle` | 실행 순서, 메시지, 상태 중 질문의 중심을 고름 |
| ETL, 데이터 계보, 저장소와 소비자 연결 | `archify / dataflow` | 선은 이동 관계를 뜻함. 수량을 선 굵기로 표현하지 않음 |
| 부서별 인계, 사용자 여정, 정책 비교, 개념 설명 | `diagram-design` | 역할별 레인이나 편집형 설명 구조가 필요한 경우 |
| ER, SQL 스키마, UML 클래스, 코드 의존성 | `diagram-design` | 필드, 제약, 상속, 의존 관계가 중심. 서비스 배치도와 구분 |
| 일정, 작업 기간, 조직, 집합, 우선순위 | `diagram-design` | Timeline, Gantt, Org chart, Venn, Quadrant 등 |
| 표나 CSV의 측정값, KPI, 시계열, 분포, 구성비 | `lieflat-charts` | 데이터의 단위와 집계 기준으로 후보를 고름 |
| 네트워크나 계층 | 의미에 따라 선택 | 실행 구성은 archify, 조직과 코드 의존성은 diagram-design, 관측된 관계 데이터 탐색과 가중치 분석은 lieflat |
| 접근 권한 행렬 또는 수치 행렬 | 의미에 따라 선택 | 역할별 허용 여부는 diagram-design의 DP security matrix, 셀별 측정량은 lieflat의 heatmap |
| 기존 앱에 들어갈 차트 컴포넌트 | 저장소의 기존 구현 | 사용 중인 라이브러리와 디자인 시스템을 먼저 재사용. 독립 HTML 스킬을 새 앱 의존성으로 취급하지 않음 |
| Git에서 계속 편집할 간단한 도식 | 요청한 기존 형식 | Mermaid나 기존 SVG가 적합하면 유지. 별도 HTML 변환을 강제하지 않음 |

수치 차트는 lieflat을 우선한다. 사용자가 Radar나 Polar처럼 번들에 있는 특정 도식을
지정했거나, lieflat의 이용 조건이나 실행 요건이 맞지 않는 경우에는 기존 차트 구현 또는
diagram-design의 해당 수치 유형을 사용할 수 있다. 이때도 실제 값, 단위, 축과 비례를 검증한다.
그림이 단순하다는 이유로 수치를 임의의 장식 크기로 바꾸지 않는다.

구조와 성능 수치를 함께 설명해야 하면 두 figure로 나눈다. 별도 파일로 줄지 한 보고서에
배치할지는 요청한 결과물에 맞춘다. 같은 그림에 서로 다른 스킬의 배치 규칙을 혼합하지 않는다.

## 2. Archify: 번들에서 지원하는 다섯 유형

`archify` 스킬 루트의 `SKILL.md`, 번들 2.16.0 기준이다.
`schemas/common.schema.json`, 선택한 스키마 하나와 대응 예제 하나를 읽고 JSON을 작성한다.
최신 업스트림의 추가 유형을 현재 번들이 지원한다고 추정하지 않는다.

| 유형 | 질문 | 스키마 / 예제, Archify 스킬 루트 기준 |
|---|---|---|
| `architecture` | 무엇이 연결되어 어디에서 실행되는가 | `schemas/architecture.schema.json` / `examples/web-app.architecture.json` |
| `workflow` | 어떤 순서와 분기로 작업하는가 | `schemas/workflow.schema.json` / `examples/agent-tool-call.workflow.json` |
| `sequence` | 누가 언제 호출하고 응답하는가 | `schemas/sequence.schema.json` / `examples/cache-miss-request.sequence.json` |
| `dataflow` | 데이터가 어디서 와서 어디로 가는가 | `schemas/dataflow.schema.json` / `examples/product-analytics.dataflow.json` |
| `lifecycle` | 어떤 사건으로 상태가 바뀌는가 | `schemas/lifecycle.schema.json` / `examples/agent-run.lifecycle.json` |

새 workflow는 `schema_version: 2`를 사용한다. 기존 v1 고정 좌표를 보존하는 작업은 v1을
유지할 수 있다. Mermaid를 다시 그리는 요청은 의미로 분류한다. `flowchart`는 workflow 또는
architecture, `sequenceDiagram`은 sequence, `stateDiagram`은 lifecycle이다.
Mermaid 원문 유지 요청은 변환하지 않는다.

## 3. Diagram Design: 필요한 참고 파일만 선택

`diagram-design` 스킬 루트의 `SKILL.md` 유형표가 정본이다.
아래 경로는 Diagram Design 스킬 루트 기준이며, 한 요청에 해당하는 파일만 고른다.

| 상황 | `references/`에서 선택 |
|---|---|
| 역할별 인계, 경험, 출시 범위 | `type-swimlane.md`, `type-process.md`, `type-journey.md`, `type-story-map.md` |
| 데이터 모델, 물리 테이블, 클래스 | `type-er.md`, `type-db-schema.md`, `type-uml-class.md` |
| 일정과 작업 현황 | `type-timeline.md`, `type-gantt.md`, `type-kanban.md` |
| 조직, 계층, 집합, 책임 | `type-org-chart.md`, `type-tree.md`, `type-nested.md`, `type-venn.md`, `type-layers.md` |
| 판단과 원인 분석 | `type-quadrant.md`, `type-fishbone.md`, `type-wardley.md`, `type-dependency.md` |
| 특정 수치 도식이 필요한 경우 | `type-radar.md`, `type-polar.md`, `type-bar.md`, `type-line.md`, `type-scatter.md`, `type-treemap.md`, `type-sankey.md` |

정책의 pass/fail 비교, 대기열 병목, 보완 통제 계층처럼 행동 의미가 중요할 때만
`references/semantic-patterns.md`를 추가로 읽는다. 애니메이션은 요청하거나 의미 전달에
필요할 때 `references/animation.md`를 읽는다. import/export와 스타일 프로필은
[설정 가이드](visualization-setup.md#diagram-design-설정과-검증)에서 해당 절차로 연결한다.

Sankey의 폭은 실제 양을 뜻한다. 일반 작업 순서에 폭을 임의로 부여하지 않는다.
Radar는 같은 기준으로 해석 가능한 지표인지 확인하고, Polar는 순환 범주인지 확인한다.

## 4. Lieflat: 데이터 형태로 후보를 좁힘

`lieflat-charts` 스킬 루트의 `SKILL.md`와 같은 루트의
`catalog.md`에 실제로 있는 ID와 구현을 사용한다. 번호가 연속이거나 카탈로그 제목의
개수만큼 기능이 존재한다고 가정하지 않는다. 예를 들어 현재 목록에 L18은 없다.

기본은 차트다. 보고서 전체를 명시 요청할 때만 `report-catalog.md`와 R01–R12를 읽는다.
Lupi Editorial / Basics의 주력 후보 L1–L15와 F1–F13을 비교하고, 세 후보가 안 되면 존재하는
후보만 비교한다. Glance는 앞 두 계열이 맞지 않거나 dashboard, 모니터링, 빠른 판단을
명시 요청할 때 선택한다. 선택 이유를 간단히 남기며 후보를 모두 그릴 필요는 없다.

| 데이터 형태 | 첫 후보 / 주의점 |
|---|---|
| 소수 범주 비교 | F1 Rung Bars, F5 Tick Rows, L2 Dot Cascade. 긴 이름은 가로 레이아웃 우선 |
| 독립적인 다중 선택 비율 | L15 Ballot Tally. 합계가 100%를 넘을 수 있으므로 구성비로 바꾸지 않음 |
| 합계 100% 구성 | F4 Tick Donut, L14 Hundred Field. 비율의 분모와 반올림 명시 |
| 범주별 분할 구성 | F7 Stacked Rungs |
| 범주별 전후 비교 | F6 Paired Rungs, F12 Dumbbell Queue |
| 시간별 실측 추이 | F2 Hairline Line, F3 Hairline Area, L3 Barcode Lollipop. 날짜 범위와 해상도 확인 |
| 단계별 실제 이탈 인원 | L13 Hourglass Stream. 개념적 단계 설명은 diagram-design |
| 증가와 감소의 분해 | F9 Rung Waterfall |
| 두 연속 변수의 관계 | F8 Plumb Scatter. 면적을 더하면 반지름에 값을 그대로 쓰지 않음 |
| 빈도 분포 | F14 Rung Histogram. 구간과 단위를 명시 |
| 범주 조합별 측정량 | L4 Arc Matrix, L9 Bubble Almanac. 행렬 구조가 중심이면 L16 Matrix Heat 검토 |
| 계층별 실제 가중치 | F13 Nested Treemap. ECharts 의존성이 있음. 가중치 없는 계층은 diagram-design |
| 생존, 휴면, 재출시 기록 | L11 Trend Lineage. 순위 변화와 실행 상태 머신으로 오인하지 않음 |
| 시점별 순위 | G21 Rank Strip 검토. 동적 경주를 요청하면 G16 Bar Race |
| 집계된 양의 분기와 합류 | G22 Aggregate Sankey 검토. 개별 경로 조회가 필요하면 B3 Threads |

주력에 해당 인코딩이 없는 다섯 형태는 바로 해당 후보를 사용한다:
OHLC → F17, 다섯 수 요약과 이상치 → F15, 개체별 3–6개 연속 차원 → L20,
연간 달력 열지도 → L17, 연속 시간의 다중 구성과 총량 → F16.
그 외 보조 후보 L16, L19, F14, G19–G22는 주력이 맞지 않는 이유를 확인한다.

Maps M1/M2는 지도를 명시 요청할 때만 사용하며 각각 미국 주 / 세계 국가 범위다.
B1/B2는 실제 관계 데이터의 확대 탐색이 필요할 때 선택한다. 시스템 토폴로지를 장식적인
force graph로 바꾸지 않는다. 템플릿은 gallery 전체가 아니라 선택한 카드와 대응 렌더링
코드를 가져온다. 스타일과 글꼴, 라이선스, 외부 의존성은 설정 가이드에서 확인한다.
