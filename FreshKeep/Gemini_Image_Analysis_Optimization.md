# Gemini Image Analysis Optimization Plan

FreshKeep의 `analyzeIngredients` 흐름을 빠르게 만들기 위한 개선 계획입니다.

현재 구조:

- iOS 앱이 촬영/선택한 이미지를 JPEG base64로 변환
- Cloud Function `analyzeIngredients`가 Gemini API에 이미지와 prompt 전달
- Gemini 응답 전체를 앱으로 반환
- iOS 앱이 응답 텍스트에서 JSON을 다시 추출하고 decode

목표:

- 이미지 분석 체감 대기시간 단축
- 식재료 인식 품질 유지
- JSON 파싱 실패율 감소
- 무료 사용량 안에서 테스트 가능한 모델 후보 선정

## 1. 이미지 Resize 및 품질 조정

### 문제

현재 iOS 코드에서는 원본 `UIImage`를 바로 JPEG 0.8로 변환해 전송한다.

```swift
guard let imageData = image.jpegData(compressionQuality: 0.8) else {
    throw GeminiServiceError.invalidImage
}
let base64Image = imageData.base64EncodedString()
```

카메라 원본 이미지는 보통 해상도가 크고, base64 인코딩은 원본 binary보다 전송 크기가 커진다. 식재료 인식에 필요한 정보보다 훨씬 많은 픽셀을 업로드하게 되어 네트워크 시간이 늘어날 수 있다.

### 제안

처음 요청에는 보수적으로 아래 설정을 사용한다.

```text
maxDimension: 1280px
jpegQuality: 0.65
```

실패 또는 낮은 품질 결과가 의심되는 경우 fallback 요청을 사용한다.

```text
fallback maxDimension: 1600px
fallback jpegQuality: 0.75
```

### 판단 기준

압축은 “화질을 무작정 낮추는 것”이 아니라 “식재료 인식에 불필요한 픽셀 수를 줄이는 것”으로 접근한다.

추천 실험:

- 원본 대비 1280px/0.65 결과 비교
- 식재료 누락 수
- 잘못 인식된 식재료 수
- 앱 요청 시작부터 결과 표시까지 걸린 시간
- 업로드 base64 문자열 길이

## 2. Cloud Function JSON Schema 적용

### 문제

현재 Cloud Function은 prompt에서 “JSON 배열 포맷만 반환해”라고 요청하지만, API 레벨에서 JSON schema를 강제하지 않는다.

```js
async function callGeminiAPI(apiKey, parts) {
  return await axios.post(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.0-flash:generateContent?key=${apiKey}`,
    { contents: [{ parts: parts }] },
  );
}
```

이 방식은 다음 문제가 생길 수 있다.

- Gemini가 ```json 코드블록을 붙일 수 있음
- 설명 문장이 섞일 수 있음
- iOS에서 regex로 JSON만 다시 뽑아야 함
- 파싱 실패 시 재시도 가능성이 커짐

### 제안

`generationConfig`에 structured output을 적용한다.

공식 문서 기준 Gemini API는 JSON Schema에 맞는 응답 생성을 지원한다. 이 기능은 데이터 추출과 구조화된 분류에 적합하다고 안내되어 있다.  
Source: [Google AI Developers - Structured outputs](https://ai.google.dev/gemini-api/docs/structured-output)

목표 응답 형태:

```json
{
  "items": [
    {
      "name": "우유",
      "expiryDays": 7
    }
  ]
}
```

권장 schema:

```js
const ingredientSchema = {
  type: "object",
  properties: {
    items: {
      type: "array",
      maxItems: 8,
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          expiryDays: { type: "integer" },
        },
        required: ["name", "expiryDays"],
      },
    },
  },
  required: ["items"],
};
```

권장 generation 설정:

```js
generationConfig: {
  responseMimeType: "application/json",
  responseSchema: ingredientSchema,
  temperature: 0,
  maxOutputTokens: 512,
}
```

주의:

- 현재 공식 문서의 최신 REST 예시는 `responseFormat.text.mimeType/schema` 형태를 보여준다.
- 기존 `v1beta/models/...:generateContent` raw REST 형식과 실제 지원 필드명은 배포 전 emulator 또는 curl로 검증한다.
- 가능하면 `@google/genai` SDK 도입도 고려한다. 공식 JavaScript 예시는 SDK와 schema 변환을 사용한다.

### 추가 개선

Cloud Function에서 Gemini 원본 응답 전체를 그대로 앱으로 보내지 말고, 서버에서 한 번 파싱한 뒤 앱에는 최소 JSON만 반환한다.

현재:

```js
res.status(200).send(response.data);
```

목표:

```js
res.status(200).json({ items });
```

iOS 앱은 `GeminiRawResponse`를 거치지 않고 바로 `{ items: [...] }`를 decode할 수 있다.

## 3. LLM Model 후보

현재 `index.js`는 아래 모델을 사용한다.

```text
gemini-3.0-flash
```

공식 Gemini API 모델/가격 문서를 확인한 결과, FreshKeep의 이미지 기반 식재료 추출에는 아래 모델들을 후보로 둔다.  
Sources:

- [Google AI Developers - Models](https://ai.google.dev/gemini-api/docs/models)
- [Google AI Developers - Pricing](https://ai.google.dev/gemini-api/docs/pricing)
- [Google AI Developers - Rate limits](https://ai.google.dev/gemini-api/docs/rate-limits)

### 후보 1. `gemini-3.1-flash-lite`

용도:

- 1차 기본 분석 모델
- 식재료 이름 추출, 짧은 JSON 생성, 단순 데이터 처리

공식 설명:

- 비용 효율 중심 모델
- high-volume agentic tasks, translation, simple data processing에 최적화
- models 페이지에서는 Gemini 3.1 Flash-Lite가 stable로 표시됨

무료 사용량:

- Pricing 문서 기준 Free Tier에서 input price가 free of charge
- text/image/video 입력에 대해 paid tier 가격은 $0.25 / 1M tokens
- output price도 Free Tier에서 free of charge
- paid tier output은 $1.50 / 1M tokens

무료 사용량 용량:

- 공개 문서가 고정된 RPM/TPM/RPD 숫자를 모델별로 명시하지 않고, active rate limit은 AI Studio에서 확인하라고 안내한다.
- Rate limits 문서 기준 제한은 RPM, TPM, RPD 세 축으로 적용된다.
- Rate limits는 프로젝트 단위이며, RPD는 Pacific Time 자정에 reset된다.
- 따라서 실제 무료 용량은 [AI Studio rate limit page](https://aistudio.google.com/)에서 현재 프로젝트 기준으로 확인해야 한다.

판단:

- 가장 먼저 테스트할 모델.
- 정확도가 유지되면 기본 모델로 사용하기 좋다.
- 음식명 인식이 약하면 fallback을 둔다.

### 후보 2. `gemini-3.5-flash`

용도:

- 품질과 속도 균형 모델
- Flash-Lite에서 식재료 누락이 많을 때 기본 또는 fallback 후보

공식 설명:

- models 페이지에서 stable로 표시됨
- pricing 문서에서는 speed와 intelligence를 함께 강조

무료 사용량:

- Pricing 문서 기준 Standard Free Tier에서 input price가 free of charge
- output price도 Free Tier에서 free of charge
- paid tier input은 $1.50 / 1M tokens
- paid tier output은 $9.00 / 1M tokens

무료 사용량 용량:

- 공개 문서가 고정된 무료 RPM/TPM/RPD 수치를 제공하지 않음.
- AI Studio에서 프로젝트의 active rate limits를 확인해야 함.

판단:

- 현재 `gemini-3.0-flash`에서 교체 테스트할 안정 후보.
- Flash-Lite보다 비싸지만 인식 품질이 더 안정적일 수 있다.

### 후보 3. `gemini-3-flash-preview`

용도:

- 실험 후보
- 속도와 품질이 좋을 가능성은 있지만 preview 모델이라 운영 기본값으로는 신중하게 사용

공식 설명:

- pricing 문서에 `gemini-3-flash-preview`가 존재
- preview 모델은 rate limit이 더 제한적일 수 있음

무료 사용량:

- Pricing 문서 기준 Standard Free Tier에서 input price가 free of charge
- text/image/video 입력 paid tier는 $0.50 / 1M tokens
- output price도 Free Tier에서 free of charge
- paid tier output은 $3.00 / 1M tokens

무료 사용량 용량:

- 공개 문서가 고정된 무료 RPM/TPM/RPD 수치를 제공하지 않음.
- Rate limits 문서에 따르면 preview/experimental 모델은 rate limit이 더 제한적이다.

판단:

- 테스트는 가능하지만 앱의 기본 운영 모델로는 stable 모델을 우선한다.

### 제외 또는 후순위

`gemini-3.1-pro-preview`

- Free Tier input/output이 pricing 문서에서 not available로 표시된다.
- 식재료 목록 추출에는 과한 모델일 가능성이 높다.
- latency와 비용 측면에서 FreshKeep의 기본 분석에는 부적합하다.

`gemini-3.1-flash-image`, `gemini-3-pro-image`

- 이미지 생성/편집 모델 성격이 강하다.
- FreshKeep의 목표는 이미지 이해 후 JSON 추출이므로 우선순위가 낮다.

## 권장 실험 순서

### Step 1. 측정 로그 추가

Cloud Function에 다음 시간을 기록한다.

```text
requestStart
imageBase64Length
geminiStart
geminiEnd
totalMs
model
itemsCount
```

## 단계별 측정 설계

포트폴리오에 “무엇 때문에 얼마나 빨라졌는지”를 쓰기 위해 세 가지 변경점을 한 번에 적용하지 않는다. 아래 순서로 누적 적용하면서 같은 이미지 세트로 반복 측정한다.

### Baseline. 현재 구조 측정

변경 전 현재 구조를 먼저 측정한다.

```text
이미지: 원본 JPEG 0.8
JSON: prompt로만 JSON 요청, schema 없음
모델: 현재 Cloud Function 모델
```

측정 목적:

- 개선 전 기준 시간 확보
- 포트폴리오의 “기존 N초” 숫자 만들기

측정 항목:

- `clientTotalMs`: 앱에서 분석 화면 진입 후 결과 표시까지 걸린 전체 시간
- `clientImageEncodeMs`: 앱에서 이미지 JPEG/base64 준비에 걸린 시간
- `imageBytes`: 서버로 보내기 전 JPEG binary 크기
- `base64Length`: 서버로 보내는 base64 문자열 길이
- `serverTotalMs`: Cloud Function 전체 처리 시간
- `geminiMs`: Cloud Function 내부 Gemini API 호출 시간
- `itemsCount`: 인식된 식재료 개수
- `success`: 성공 여부

### Experiment 1. 이미지 변경만 적용

첫 번째 실험에서는 이미지 resize와 JPEG 품질 조정만 적용한다. JSON 응답 구조와 모델은 baseline과 동일하게 유지한다.

```text
이미지: 1280px / JPEG 0.65
JSON: 기존 방식 유지
모델: 기존 모델 유지
```

측정 목적:

- 이미지 전송량 감소가 전체 시간에 얼마나 기여하는지 확인
- 식재료 인식 품질이 유지되는지 확인

비교 지표:

- `imageBytes` 감소율
- `base64Length` 감소율
- `clientImageEncodeMs` 변화
- `clientTotalMs` 변화
- `itemsCount`와 누락/오인식 여부

포트폴리오 표현 예시:

```text
이미지 리사이징과 JPEG 압축을 적용해 전송 이미지 크기를 평균 A MB에서 B KB로 줄였고, 전체 분석 시간을 N초에서 M초로 단축했습니다.
```

### Experiment 2. 이미지 변경 + JSON Schema 적용

두 번째 실험에서는 Experiment 1의 이미지 최적화를 유지한 상태에서 Cloud Function의 JSON 응답 구조를 개선한다.

```text
이미지: 1280px / JPEG 0.65
JSON: JSON schema 또는 structured output 적용
모델: 기존 모델 유지
```

측정 목적:

- JSON 응답 강제화가 Gemini 응답 시간과 파싱 안정성에 미치는 영향 확인
- 앱의 regex 기반 JSON 추출을 줄이거나 제거할 수 있는지 확인

비교 지표:

- `geminiMs` 변화
- `serverParsingMs` 변화
- `clientTotalMs` 변화
- JSON 파싱 실패 횟수
- 재시도 횟수

포트폴리오 표현 예시:

```text
JSON Schema 기반 응답 강제화를 적용해 파싱 실패 가능성을 줄이고, Gemini 응답 처리 시간을 N초에서 M초로 개선했습니다.
```

### Experiment 3. 이미지 변경 + JSON Schema + Stable Model 변경

세 번째 실험에서는 이미지 최적화와 JSON schema를 유지한 상태에서 모델만 변경한다.

```text
이미지: 1280px / JPEG 0.65
JSON: JSON schema 또는 structured output 적용
모델: stable 후보 모델로 변경
```

측정 목적:

- preview 모델 사용에 따른 운영 불안정성을 줄이고 stable 모델로 교체
- 모델 변경이 Gemini API 호출 시간과 인식 품질에 미치는 영향 확인

비교 후보:

```text
A: gemini-3.1-flash-lite
B: gemini-3.5-flash
```

`gemini-3-flash-preview`는 실험 후보로 둘 수 있지만, preview 모델 회피가 목적이라면 운영 후보에서는 제외한다.

비교 지표:

- `geminiMs` 변화
- `clientTotalMs` 변화
- 식재료 누락 수
- 잘못 인식된 식재료 수
- API 오류 또는 rate limit 발생 여부

포트폴리오 표현 예시:

```text
preview 모델을 stable Gemini 모델로 교체해 운영 안정성을 높이고, Gemini API 호출 시간을 평균 N초에서 M초로 단축했습니다.
```

### 최종 비교표

최종적으로 아래 표 형태로 정리한다.

| 단계 | 이미지 | JSON | 모델 | clientTotalMs 평균 | geminiMs 평균 | imageBytes 평균 | 성공률 |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| Baseline | 원본 / 0.8 | Prompt only | 기존 모델 | - | - | - | - |
| Exp 1 | 1280px / 0.65 | Prompt only | 기존 모델 | - | - | - | - |
| Exp 2 | 1280px / 0.65 | Schema | 기존 모델 | - | - | - | - |
| Exp 3A | 1280px / 0.65 | Schema | gemini-3.1-flash-lite | - | - | - | - |
| Exp 3B | 1280px / 0.65 | Schema | gemini-3.5-flash | - | - | - | - |

개선율 계산식:

```text
개선율(%) = (Baseline 평균 시간 - 개선 후 평균 시간) / Baseline 평균 시간 * 100
```

예시:

```text
(12.4초 - 5.8초) / 12.4초 * 100 = 53.2%
```

### 측정 로그 형식

요청 1회마다 아래 형태로 로그를 남긴다.

```json
{
  "requestId": "UUID",
  "experiment": "baseline",
  "model": "gemini-3.0-flash",
  "imageMaxDimension": null,
  "jpegQuality": 0.8,
  "imageBytes": 3800000,
  "base64Length": 5066667,
  "clientImageEncodeMs": 180,
  "clientTotalMs": 12400,
  "serverTotalMs": 8100,
  "geminiMs": 7100,
  "serverParsingMs": 12,
  "itemsCount": 5,
  "success": true
}
```

권장 실험 횟수:

- 각 단계별 최소 10회
- 가능하면 같은 이미지 세트 5장 이상
- 평균, 중앙값, p95를 같이 기록

### 측정 로그 확인 방법

iOS 앱과 Cloud Function은 같은 `requestId`를 공유한다. 앱에서 분석을 실행하면 Xcode console과 Firebase Functions logs에 각각 `[PERF]` 로그가 남는다.

Xcode console 예시:

```text
[PERF] {"base64Length":5066667,"clientImageEncodeMs":180.2,"clientNetworkRoundTripMs":8200.4,"clientTotalMs":12400.1,"experiment":"baseline","geminiMs":7100,"imageBytes":3800000,"itemsCount":5,"jpegQuality":0.8,"model":"gemini-3.0-flash","requestId":"...","serverTotalMs":8100,"success":true}
```

Firebase Functions logs 예시:

```text
[PERF] {
  requestId: "...",
  experiment: "baseline",
  model: "gemini-3.0-flash",
  base64Length: 5066667,
  serverTotalMs: 8100,
  geminiMs: 7100,
  itemsCount: null,
  success: true
}
```

확인 순서:

1. `functions/index.js`를 배포한다.
2. Xcode에서 앱을 실행한다.
3. 사진 분석을 한 번 실행한다.
4. Xcode console에서 `[PERF]`를 검색한다.
5. Firebase Functions logs에서도 같은 `requestId`를 검색한다.
6. 각 실험 단계별 로그를 표에 모아 평균, 중앙값, p95를 계산한다.

### Step 2. 이미지 최적화 적용

iOS에서 Gemini 전송 전 이미지를 축소한다.

```text
maxDimension: 1280px
jpegQuality: 0.65
```

실패 시 fallback:

```text
maxDimension: 1600px
jpegQuality: 0.75
```

### Step 3. JSON Schema 적용

Cloud Function에서 JSON schema 기반 structured output을 적용한다.

기대 효과:

- 출력 토큰 감소
- 앱 regex 파싱 제거 가능
- 실패/재시도 감소
- 데이터 구조 안정화

### Step 4. 모델 A/B 테스트

동일 이미지 세트로 아래 모델을 비교한다.

```text
A: gemini-3.1-flash-lite
B: gemini-3.5-flash
C: gemini-3-flash-preview
```

측정 지표:

- 평균 응답 시간
- p95 응답 시간
- 식재료 누락 수
- 잘못 인식된 식재료 수
- JSON 파싱 실패 수
- 사용량 제한 또는 오류 발생 여부

### Step 5. 운영 전략 결정

추천 기본 전략:

```text
기본: gemini-3.1-flash-lite + 1280px/0.65 + JSON schema
fallback: gemini-3.5-flash + 1600px/0.75
```

다만 실제 테스트에서 Flash-Lite가 식재료 인식 누락을 많이 만들면:

```text
기본: gemini-3.5-flash + 1280px/0.65 + JSON schema
fallback: gemini-3.5-flash + 1600px/0.75
```

## 현재 확실히 말할 수 있는 것

- 모델 변경은 도움될 수 있지만, 현재도 Flash 계열을 사용 중이라 이미지 resize/JSON schema보다 효과가 작을 수 있다.
- `gemini-3.1-flash-lite`, `gemini-3.5-flash`, `gemini-3-flash-preview`는 공식 pricing/models 문서에서 확인 가능한 모델명이다.
- Free Tier에서 일부 모델은 input/output token 가격이 free of charge로 표시된다.
- 정확한 무료 RPM/TPM/RPD 용량은 공개 문서에 고정값으로 박혀 있지 않고, AI Studio의 active rate limits에서 프로젝트별로 확인해야 한다.
