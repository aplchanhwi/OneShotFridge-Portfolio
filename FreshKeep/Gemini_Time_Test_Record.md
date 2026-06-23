# Gemini Image Analysis Time Test Record

FreshKeep 이미지 분석 속도 개선과 식재료 감지 품질을 함께 기록하기 위한 측정 문서입니다.

## Test Goal

- 분석 완료까지 걸린 전체 시간 측정
- Gemini API 호출 시간 측정
- 전송 이미지 크기 측정
- 모델 변경 후 식재료 감지 품질 확인
- 포트폴리오에 사용할 개선 수치 확보

## Current Test Setting

| 항목 | 값 |
| --- | --- |
| Model | `gemini-2.5-flash` |
| 테스트 사진 수 | 5장 |
| 반복 횟수 | 사진당 2회 |
| 단계별 총 실행 수 | 10회 |
| 측정 로그 | Xcode console `[PERF]`, Firebase Functions logs `[PERF]` |
| 감지 품질 평가 | 정답 식재료 기준 Correct / Missing / False Positive 기록 |
| 실행 방식 | 새 사진으로 넘어갈 때마다 앱을 다시 빌드 후 측정 |

## Photo Answer Key

사진 번호는 식재료 내용 기준으로 정리했습니다.

| Photo ID | File | 포함된 식재료 |
| --- | --- | --- |
| Photo 1 | `IMG_2541.jpeg` | 라이스페이퍼, 찹쌀호떡믹스, 소면 |
| Photo 2 | `IMG_2566.jpeg` | 팽이버섯, 콜라, 올리브유, 버터 |
| Photo 3 | `IMG_2594.jpeg` | 츄파춥스젤리, 고래밥과자, 고추장, 와사비 |
| Photo 4 | `IMG_2647.jpeg` | 양파, 감자, 맛술, 햇반, 계란, 우유, 닭고기, 오리고기 |
| Photo 5 | `IMG_2701.jpeg` | 돼지고기 목살, 돼지고기 앞다리, 식빵 |

## Experiment Steps

| Experiment | 이미지 설정 | JSON 설정 | Model | 목적 |
| --- | --- | --- | --- | --- |
| Baseline | Original / JPEG 0.8 | Prompt only | `gemini-2.5-flash` | 현재 기준 시간과 감지 품질 측정 |
| Image Resize | 1280px / JPEG 0.65 | Prompt only | `gemini-2.5-flash` | 이미지 크기 감소 효과 측정 |
| Image + JSON | 1280px / JPEG 0.65 | JSON Schema | `gemini-2.5-flash` | 구조화 응답 적용 후 시간과 안정성 측정 |

## Quality Metrics

| 지표 | 의미 |
| --- | --- |
| Correct | 정답 식재료 중 Gemini가 맞게 감지한 개수 |
| Missing | 정답 식재료 중 Gemini가 감지하지 못한 개수 |
| False Positive | 사진에 없는데 Gemini가 추가로 감지한 식재료 개수 |
| Recall | `Correct / 정답 식재료 개수` |
| Precision | `Correct / Gemini가 감지한 식재료 개수` |

식재료명이 완전히 같지 않아도 같은 재료로 판단 가능하면 Correct로 기록합니다.

예시:

- `콜라`와 `펩시콜라`는 같은 재료로 판단 가능
- `돼지고기`처럼 너무 넓은 표현은 상황에 따라 부분 정답으로 메모
- 브랜드명만 맞고 식재료명이 애매하면 Notes에 기록

## Baseline Runs

| Run ID | Photo | Attempt | Expected Count | Detected Items | Correct | Missing | False Positive | Recall | Precision | Image Bytes | Base64 Length | Client Encode ms | Client Network ms | Client Total ms | Server Total ms | Gemini ms | Success | Notes |
| --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| B-01 | Photo 1 - `IMG_2541.jpeg` | 1 | 3 | 라이스페이퍼, 찹쌀호떡믹스, 소면 | 3 | 0 | 0 | 100% | 100% | 3,908,051 | 5,210,736 | 112.42 | 21,229.67 | 21,400.75 | 12,273 | 12,273 | TRUE | 첫 번째 사진 출력값 |
| B-02 | Photo 1 - `IMG_2541.jpeg` | 2 | 3 | 라이스페이퍼, 참쌀호떡믹스, 소면 | 3 | 0 | 0 | 100% | 100% | 3,908,051 | 5,210,736 | 119.75 | 15,739.48 | 15,881.41 | 8,846 | 8,846 | TRUE | `찹쌀호떡믹스`를 `참쌀호떡믹스`로 표기 |
| B-03 | Photo 2 - `IMG_2566.jpeg` | 1 | 4 | 버터, 팽이버섯, 펩시, 올리브 오일 | 4 | 0 | 0 | 100% | 100% | 4,098,514 | 5,464,688 | 111.90 | 24,724.83 | 24,895.15 | 14,741 | 14,741 | TRUE | `펩시`는 콜라, `올리브 오일`은 올리브유로 처리 |
| B-04 | Photo 2 - `IMG_2566.jpeg` | 2 | 4 | 버터, 팽이버섯, 펩시 제로 슈거, 올리브 오일 | 4 | 0 | 0 | 100% | 100% | 4,098,514 | 5,464,688 | 120.90 | 13,236.51 | 13,382.33 | 8,240 | 8,240 | TRUE | `펩시 제로 슈거`는 콜라로 처리 |
| B-05 | Photo 3 - `IMG_2594.jpeg` | 1 | 4 | 고래밥, 태양초 고추장, 와사비 페이스트, 츄파춥스 플러피 팬더 젤리 | 4 | 0 | 0 | 100% | 100% | 4,520,354 | 6,027,140 | 122.54 | 22,738.30 | 22,921.42 | 14,804 | 14,804 | TRUE | 제품명 확장 표기, 정답 4개 모두 감지 |
| B-06 | Photo 3 - `IMG_2594.jpeg` | 2 | 4 | 고래밥, 고추장, 와사비 페이스트, 츄파춥스 젤리 | 4 | 0 | 0 | 100% | 100% | 4,520,354 | 6,027,140 | 132.16 | 24,843.10 | 25,000.86 | 20,213 | 20,213 | TRUE | 정답 4개 모두 감지 |
| B-07 | Photo 4 - `IMG_2647.jpeg` | 1 | 8 | 양파, 생닭고기, 감자, 요리 식초, 훈제 오리 슬라이스, 계란, 즉석밥, 우유 | 7 | 1 | 1 | 87.5% | 87.5% | 3,716,405 | 4,955,208 | 108.31 | 21,930.01 | 22,109.62 | 16,297 | 16,297 | TRUE | `맛술`을 `요리 식초`로 오인식 |
| B-08 | Photo 4 - `IMG_2647.jpeg` | 2 | 8 | 양파, 생닭고기, 감자, 맛술, 훈제 오리 슬라이스, 계란, 즉석밥, 멸균우유 | 8 | 0 | 0 | 100% | 100% | 3,716,405 | 4,955,208 | 117.15 | 25,243.89 | 25,388.87 | 20,611 | 20,611 | TRUE | `멸균우유`는 우유로 처리 |
| B-09 | Photo 5 - `IMG_2701.jpeg` | 1 | 3 | 돼지고기 목살, 돼지고기 안심, 식빵 | 2 | 1 | 1 | 66.7% | 66.7% | 3,075,607 | 4,100,812 | 95.54 | 11,950.13 | 12,112.26 | 5,474 | 5,474 | TRUE | `돼지고기 앞다리`를 `돼지고기 안심`으로 오인식 |
| B-10 | Photo 5 - `IMG_2701.jpeg` | 2 | 3 | 돼지고기, 식빵 | 2 | 1 | 0 | 66.7% | 100% | 3,075,607 | 4,100,812 | 106.32 | 11,518.93 | 11,643.92 | 7,185 | 7,185 | TRUE | 돼지고기 두 부위를 `돼지고기` 하나로 뭉개서 감지 |

## Image Resize Runs

| Run ID | Photo | Attempt | Expected Count | Detected Items | Correct | Missing | False Positive | Recall | Precision | Image Bytes | Base64 Length | Client Encode ms | Client Network ms | Client Total ms | Server Total ms | Gemini ms | Success | Notes |
| --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| I-01 | Photo 1 - `IMG_2541.jpeg` | 1 | 3 | 라이스페이퍼, 찹쌀호떡믹스, 소면 | 3 | 0 | 0 | 100% | 100% | 358,818 | 478,424 | 332.02 | 7,215.08 | 7,591.64 | 5,985 | 5,985 | TRUE | 이미지 리사이즈 1번째 결과 |
| I-02 | Photo 1 - `IMG_2541.jpeg` | 2 | 3 | 찹쌀호떡믹스, 라이스페이퍼, 소면 | 3 | 0 | 0 | 100% | 100% | 358,818 | 478,424 | 112.36 | 9,310.89 | 9,430.67 | 8,345 | 8,345 | TRUE | 이미지 리사이즈 2번째 결과 |
| I-03 | Photo 2 - `IMG_2566.jpeg` | 1 | 4 | 버터, 팽이버섯, 펩시 제로 슈거, 올리브 오일 | 4 | 0 | 0 | 100% | 100% | 407,058 | 542,744 | 119.94 | 10,772.20 | 10,935.86 | 9,447 | 9,447 | TRUE | `펩시 제로 슈거`는 콜라로 처리 |
| I-04 | Photo 2 - `IMG_2566.jpeg` | 2 | 4 | 팽이버섯, 버터, 펩시 제로 슈거, 올리브 오일 | 4 | 0 | 0 | 100% | 100% | 407,058 | 542,744 | 120.78 | 8,659.91 | 8,786.51 | 7,589 | 7,589 | TRUE | `펩시 제로 슈거`는 콜라로 처리 |
| I-05 | Photo 3 - `IMG_2594.jpeg` | 1 | 4 | 꼬깔콘, 고추장, 와사비 페이스트, 츄파춥스 말랑말랑 판다 | 3 | 1 | 1 | 75.0% | 75.0% | 409,068 | 545,424 | 118.66 | 14,594.12 | 14,756.12 | 13,411 | 13,411 | TRUE | `츄파춥스 말랑말랑 판다`는 츄파춥스젤리로 처리, `고래밥`을 `꼬깔콘`으로 오인식 |
| I-06 | Photo 3 - `IMG_2594.jpeg` | 2 | 4 | 고래밥 (스낵), 고추장, 와사비 페이스트, 츄파춥스 플러피 팬더 (젤리) | 4 | 0 | 0 | 100% | 100% | 409,068 | 545,424 | 186.71 | 10,417.00 | 10,613.65 | 9,431 | 9,431 | TRUE | 정답 4개 모두 감지 |
| I-07 | Photo 4 - `IMG_2647.jpeg` | 1 | 8 | 양파, 닭고기, 마, 맛술, 계란, 즉석밥, 우유, 훈제 오리 슬라이스 | 7 | 1 | 1 | 87.5% | 87.5% | 363,503 | 484,672 | 148.87 | 12,761.01 | 12,987.58 | 9,904 | 9,904 | TRUE | `감자`를 `마`로 오인식 |
| I-08 | Photo 4 - `IMG_2647.jpeg` | 2 | 8 | 양파, 생닭고기, 마, 계란, 맛술, 즉석밥, 오리훈제 슬라이스, 우유 | 7 | 1 | 1 | 87.5% | 87.5% | 363,503 | 484,672 | 128.20 | 7,916.24 | 13,788.96 | 6,827 | 6,827 | TRUE | `감자`를 `마`로 오인식, retryAttempt 2 |
| I-09 | Photo 5 - `IMG_2701.jpeg` | 1 | 3 | 돼지고기 목살, 식빵, 돼지고기 등심 | 2 | 1 | 1 | 66.7% | 66.7% | 348,264 | 464,352 | 128.00 | 6,628.24 | 6,816.71 | 5,202 | 5,202 | TRUE | `돼지고기 앞다리`를 `돼지고기 등심`으로 오인식 |
| I-10 | Photo 5 - `IMG_2701.jpeg` | 2 | 3 | 돼지고기 (앞다리살), 돼지고기, 식빵 | 3 | 0 | 0 | 100% | 100% | 348,264 | 464,352 | 126.57 | 5,170.84 | 5,307.63 | 4,487 | 4,487 | TRUE | `돼지고기 목살`을 세부 부위 없이 `돼지고기`로 감지 |

## Image + JSON Runs

| Run ID | Photo | Attempt | Expected Count | Detected Items | Correct | Missing | False Positive | Recall | Precision | Image Bytes | Base64 Length | Client Encode ms | Client Network ms | Client Total ms | Server Total ms | Gemini ms | Success | Notes |
| --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| J-01 | Photo 1 - `IMG_2541.jpeg` | 1 | 3 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| J-02 | Photo 1 - `IMG_2541.jpeg` | 2 | 3 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| J-03 | Photo 2 - `IMG_2566.jpeg` | 1 | 4 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| J-04 | Photo 2 - `IMG_2566.jpeg` | 2 | 4 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| J-05 | Photo 3 - `IMG_2594.jpeg` | 1 | 4 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| J-06 | Photo 3 - `IMG_2594.jpeg` | 2 | 4 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| J-07 | Photo 4 - `IMG_2647.jpeg` | 1 | 8 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| J-08 | Photo 4 - `IMG_2647.jpeg` | 2 | 8 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| J-09 | Photo 5 - `IMG_2701.jpeg` | 1 | 3 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| J-10 | Photo 5 - `IMG_2701.jpeg` | 2 | 3 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |

## Summary

| Experiment | Runs | Avg Client Total sec | Avg Gemini sec | Avg Image MB | Avg Recall | Avg Precision | Success Rate |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Baseline | 10 | 19.47 | 12.87 | 3.68 | 93.2% | 95.3% | 100% |
| Image Resize | 10 | 10.10 | 8.06 | 0.36 | 84.1% | 94.9% | 100% |
| Image + JSON | 10 |  |  |  |  |  |  |

## Baseline Result Summary

Baseline은 `gemini-2.5-flash`, 원본 이미지 JPEG 0.8, prompt only JSON 요청 조건으로 측정했습니다.

| 항목 | 결과 |
| --- | ---: |
| 총 실행 횟수 | 10회 |
| 성공률 | 100% |
| 평균 전체 분석 시간 | 19.47초 |
| 중앙값 전체 분석 시간 | 21.76초 |
| 평균 Gemini API 호출 시간 | 12.87초 |
| 평균 전송 이미지 크기 | 3.68MB |
| 평균 base64 길이 | 5,151,717자 |
| 전체 정답 식재료 수 | 44개 |
| Correct | 41개 |
| Missing | 3개 |
| False Positive | 2개 |
| 전체 기준 Recall | 93.2% |
| 전체 기준 Precision | 95.3% |

요약하면, baseline은 모든 요청이 성공했고 식재료 감지 품질도 전반적으로 높았습니다. 다만 평균 전체 분석 시간이 약 19.47초로 사용자가 기다리기에는 긴 편이며, 특히 돼지고기 부위처럼 세부 구분이 필요한 식재료에서 누락이나 오인식이 발생했습니다.

포트폴리오 기준으로는 이 값을 개선 전 기준선으로 사용합니다.

```text
개선 전 baseline에서 이미지 분석 완료까지 평균 19.47초가 걸렸고,
전체 정답 식재료 44개 중 41개를 감지해 Recall 93.2%, Precision 95.3%를 기록했습니다.
```

## Image Resize Result Summary

Image Resize는 `gemini-2.5-flash`, 최대 변 1280px, JPEG 0.65, prompt only JSON 요청 조건으로 측정했습니다.

| 항목 | Baseline | Image Resize | 변화량 |
| --- | ---: | ---: | ---: |
| 총 실행 횟수 | 10회 | 10회 | - |
| 성공률 | 100% | 100% | 변화 없음 |
| 평균 전체 분석 시간 | 19.47초 | 10.10초 | 9.37초 단축, 48.1% 개선 |
| 중앙값 전체 분석 시간 | 21.76초 | 10.02초 | 11.73초 단축, 53.9% 개선 |
| 평균 Gemini API 호출 시간 | 12.87초 | 8.06초 | 4.81초 단축, 37.3% 개선 |
| 평균 전송 이미지 크기 | 3.68MB | 0.36MB | 90.2% 감소 |
| 평균 base64 길이 | 5,151,717자 | 503,123자 | 90.2% 감소 |
| Correct | 41개 | 37개 | 4개 감소 |
| Missing | 3개 | 7개 | 4개 증가 |
| False Positive | 2개 | 4개 | 2개 증가 |
| 전체 기준 Recall | 93.2% | 84.1% | 9.1%p 감소 |
| 전체 기준 Precision | 95.3% | 94.9% | 0.4%p 감소 |

요약하면, 이미지 리사이징과 JPEG 압축률 변경만으로 전송 이미지 크기는 평균 3.68MB에서 0.36MB로 약 90.2% 감소했습니다. 그 결과 평균 전체 분석 시간은 19.47초에서 10.10초로 약 48.1% 단축되었고, Gemini API 호출 시간도 12.87초에서 8.06초로 약 37.3% 줄었습니다.

다만 식재료 감지 품질은 일부 하락했습니다. 특히 `감자`를 `마`로 오인식하거나, 과자/돼지고기 부위처럼 세부 식별이 필요한 항목에서 누락 또는 오인식이 발생했습니다. 따라서 현재 설정은 속도 개선 효과는 크지만, 정확도 보존을 위해 JSON Schema 적용 후 결과 변화까지 함께 확인하는 것이 좋습니다.

포트폴리오 기준으로는 아래처럼 표현할 수 있습니다.

```text
이미지 최대 변을 1280px로 제한하고 JPEG 품질을 0.65로 조정해 평균 전송 이미지 크기를 3.68MB에서 0.36MB로 약 90.2% 줄였습니다.
그 결과 이미지 분석 완료 시간은 평균 19.47초에서 10.10초로 약 48.1% 단축되었고,
Gemini API 호출 시간은 평균 12.87초에서 8.06초로 약 37.3% 개선되었습니다.
```

## Improvement Formula

```text
시간 개선율(%) = (Baseline 평균 시간 - 개선 후 평균 시간) / Baseline 평균 시간 * 100
이미지 크기 감소율(%) = (Baseline 평균 imageBytes - 개선 후 평균 imageBytes) / Baseline 평균 imageBytes * 100
```

## Portfolio Sentence Template

```text
동일한 iPhone과 Wi-Fi 환경에서 식재료 사진 5장을 단계별로 10회씩 측정했습니다.
이미지 리사이징과 JSON 응답 구조화를 적용해 이미지 분석 완료 시간을 평균 N초에서 M초로 단축하여 약 P% 개선했고,
식재료 감지 Recall은 R%, Precision은 Q% 수준을 유지했습니다.
```

## First Baseline Raw Log

```json
{
  "requestId": "6829F355-E4DD-421E-AF22-B1BA380E706B",
  "experiment": "baseline",
  "model": "gemini-2.5-flash",
  "base64Length": 5210736,
  "serverTotalMs": 12273,
  "geminiMs": 12273,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 5210736,
  "clientImageEncodeMs": 112.42401599884033,
  "clientNetworkRoundTripMs": 21229.66694831848,
  "clientTotalMs": 21400.75397491455,
  "experiment": "baseline",
  "geminiMs": 12273,
  "imageBytes": 3908051,
  "itemsCount": 3,
  "jpegQuality": 0.8,
  "model": "gemini-2.5-flash",
  "requestId": "6829F355-E4DD-421E-AF22-B1BA380E706B",
  "retryAttempt": 0,
  "serverTotalMs": 12273,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "라이스페이퍼",
    "expiryDays": 1095
  },
  {
    "name": "찹쌀호떡믹스",
    "expiryDays": 547
  },
  {
    "name": "소면",
    "expiryDays": 1095
  }
]
```

## Second Baseline Raw Log

```json
{
  "requestId": "05F0F801-5A49-4939-903D-7CB3F7880A06",
  "experiment": "baseline",
  "model": "gemini-2.5-flash",
  "base64Length": 5210736,
  "serverTotalMs": 8846,
  "geminiMs": 8846,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 5210736,
  "clientImageEncodeMs": 119.7500228881836,
  "clientNetworkRoundTripMs": 15739.482045173645,
  "clientTotalMs": 15881.412982940674,
  "experiment": "baseline",
  "geminiMs": 8846,
  "imageBytes": 3908051,
  "itemsCount": 3,
  "jpegQuality": 0.8,
  "model": "gemini-2.5-flash",
  "requestId": "05F0F801-5A49-4939-903D-7CB3F7880A06",
  "retryAttempt": 0,
  "serverTotalMs": 8846,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "라이스페이퍼",
    "expiryDays": 730
  },
  {
    "name": "참쌀호떡믹스",
    "expiryDays": 365
  },
  {
    "name": "소면",
    "expiryDays": 730
  }
]
```

## Third Baseline Raw Log

```json
{
  "requestId": "A732BFFD-DEA0-40B3-877F-E57F03843C0F",
  "experiment": "baseline",
  "model": "gemini-2.5-flash",
  "base64Length": 5464688,
  "serverTotalMs": 14741,
  "geminiMs": 14741,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 5464688,
  "clientImageEncodeMs": 111.9009256362915,
  "clientNetworkRoundTripMs": 24724.82705116272,
  "clientTotalMs": 24895.148992538452,
  "experiment": "baseline",
  "geminiMs": 14741,
  "imageBytes": 4098514,
  "itemsCount": 4,
  "jpegQuality": 0.8,
  "model": "gemini-2.5-flash",
  "requestId": "A732BFFD-DEA0-40B3-877F-E57F03843C0F",
  "retryAttempt": 0,
  "serverTotalMs": 14741,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "버터",
    "expiryDays": 180
  },
  {
    "name": "팽이버섯",
    "expiryDays": 7
  },
  {
    "name": "펩시",
    "expiryDays": 180
  },
  {
    "name": "올리브 오일",
    "expiryDays": 365
  }
]
```

## Fourth Baseline Raw Log

```json
{
  "requestId": "E515B11D-6A5D-45FE-9056-7AEC7C56C8E2",
  "experiment": "baseline",
  "model": "gemini-2.5-flash",
  "base64Length": 5464688,
  "serverTotalMs": 8240,
  "geminiMs": 8240,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 5464688,
  "clientImageEncodeMs": 120.90492248535156,
  "clientNetworkRoundTripMs": 13236.50598526001,
  "clientTotalMs": 13382.331013679504,
  "experiment": "baseline",
  "geminiMs": 8240,
  "imageBytes": 4098514,
  "itemsCount": 4,
  "jpegQuality": 0.8,
  "model": "gemini-2.5-flash",
  "requestId": "E515B11D-6A5D-45FE-9056-7AEC7C56C8E2",
  "retryAttempt": 0,
  "serverTotalMs": 8240,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "버터",
    "expiryDays": 180
  },
  {
    "name": "팽이버섯",
    "expiryDays": 7
  },
  {
    "name": "펩시 제로 슈거",
    "expiryDays": 365
  },
  {
    "name": "올리브 오일",
    "expiryDays": 365
  }
]
```

## Fifth Baseline Raw Log

```json
{
  "requestId": "83182C17-CB53-4C96-88D8-17A3636C41BD",
  "experiment": "baseline",
  "model": "gemini-2.5-flash",
  "base64Length": 6027140,
  "serverTotalMs": 14804,
  "geminiMs": 14804,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 6027140,
  "clientImageEncodeMs": 122.53999710083008,
  "clientNetworkRoundTripMs": 22738.29996585846,
  "clientTotalMs": 22921.42105102539,
  "experiment": "baseline",
  "geminiMs": 14804,
  "imageBytes": 4520354,
  "itemsCount": 4,
  "jpegQuality": 0.8,
  "model": "gemini-2.5-flash",
  "requestId": "83182C17-CB53-4C96-88D8-17A3636C41BD",
  "retryAttempt": 0,
  "serverTotalMs": 14804,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "고래밥",
    "expiryDays": 7
  },
  {
    "name": "태양초 고추장",
    "expiryDays": 180
  },
  {
    "name": "와사비 페이스트",
    "expiryDays": 60
  },
  {
    "name": "츄파춥스 플러피 팬더 젤리",
    "expiryDays": 14
  }
]
```

## Sixth Baseline Raw Log

```json
{
  "requestId": "4C5A7356-FB03-44E2-B42C-2B7CE733DB76",
  "experiment": "baseline",
  "model": "gemini-2.5-flash",
  "base64Length": 6027140,
  "serverTotalMs": 20213,
  "geminiMs": 20213,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 6027140,
  "clientImageEncodeMs": 132.15506076812744,
  "clientNetworkRoundTripMs": 24843.096017837524,
  "clientTotalMs": 25000.85699558258,
  "experiment": "baseline",
  "geminiMs": 20213,
  "imageBytes": 4520354,
  "itemsCount": 4,
  "jpegQuality": 0.8,
  "model": "gemini-2.5-flash",
  "requestId": "4C5A7356-FB03-44E2-B42C-2B7CE733DB76",
  "retryAttempt": 0,
  "serverTotalMs": 20213,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "고래밥",
    "expiryDays": 270
  },
  {
    "name": "고추장",
    "expiryDays": 240
  },
  {
    "name": "와사비 페이스트",
    "expiryDays": 60
  },
  {
    "name": "츄파춥스 젤리",
    "expiryDays": 365
  }
]
```

## Seventh Baseline Raw Log

```json
{
  "requestId": "324CA6DA-F33B-4A3B-B48F-4AE01DB3FC65",
  "experiment": "baseline",
  "model": "gemini-2.5-flash",
  "base64Length": 4955208,
  "serverTotalMs": 16297,
  "geminiMs": 16297,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 4955208,
  "clientImageEncodeMs": 108.30700397491455,
  "clientNetworkRoundTripMs": 21930.008053779602,
  "clientTotalMs": 22109.61902141571,
  "experiment": "baseline",
  "geminiMs": 16297,
  "imageBytes": 3716405,
  "itemsCount": 8,
  "jpegQuality": 0.8,
  "model": "gemini-2.5-flash",
  "requestId": "324CA6DA-F33B-4A3B-B48F-4AE01DB3FC65",
  "retryAttempt": 0,
  "serverTotalMs": 16297,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "양파",
    "expiryDays": 45
  },
  {
    "name": "생닭고기",
    "expiryDays": 2
  },
  {
    "name": "감자",
    "expiryDays": 45
  },
  {
    "name": "요리 식초",
    "expiryDays": 365
  },
  {
    "name": "훈제 오리 슬라이스",
    "expiryDays": 10
  },
  {
    "name": "계란",
    "expiryDays": 28
  },
  {
    "name": "즉석밥",
    "expiryDays": 180
  },
  {
    "name": "우유",
    "expiryDays": 180
  }
]
```

## Eighth Baseline Raw Log

```json
{
  "requestId": "F7BD956D-D00D-445C-88C0-EDB069DAF83D",
  "experiment": "baseline",
  "model": "gemini-2.5-flash",
  "base64Length": 4955208,
  "serverTotalMs": 20611,
  "geminiMs": 20611,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 4955208,
  "clientImageEncodeMs": 117.14601516723633,
  "clientNetworkRoundTripMs": 25243.88611316681,
  "clientTotalMs": 25388.872027397156,
  "experiment": "baseline",
  "geminiMs": 20611,
  "imageBytes": 3716405,
  "itemsCount": 8,
  "jpegQuality": 0.8,
  "model": "gemini-2.5-flash",
  "requestId": "F7BD956D-D00D-445C-88C0-EDB069DAF83D",
  "retryAttempt": 0,
  "serverTotalMs": 20611,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "양파",
    "expiryDays": 60
  },
  {
    "name": "생닭고기",
    "expiryDays": 2
  },
  {
    "name": "감자",
    "expiryDays": 60
  },
  {
    "name": "맛술",
    "expiryDays": 365
  },
  {
    "name": "훈제 오리 슬라이스",
    "expiryDays": 21
  },
  {
    "name": "계란",
    "expiryDays": 28
  },
  {
    "name": "즉석밥",
    "expiryDays": 180
  },
  {
    "name": "멸균우유",
    "expiryDays": 180
  }
]
```

## Ninth Baseline Raw Log

```json
{
  "requestId": "F4C81947-BC66-41D3-83C2-E6E79824208D",
  "experiment": "baseline",
  "model": "gemini-2.5-flash",
  "base64Length": 4100812,
  "serverTotalMs": 5474,
  "geminiMs": 5474,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 4100812,
  "clientImageEncodeMs": 95.54004669189453,
  "clientNetworkRoundTripMs": 11950.134992599487,
  "clientTotalMs": 12112.255930900574,
  "experiment": "baseline",
  "geminiMs": 5474,
  "imageBytes": 3075607,
  "itemsCount": 3,
  "jpegQuality": 0.8,
  "model": "gemini-2.5-flash",
  "requestId": "F4C81947-BC66-41D3-83C2-E6E79824208D",
  "retryAttempt": 0,
  "serverTotalMs": 5474,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "돼지고기 목살",
    "expiryDays": 3
  },
  {
    "name": "돼지고기 안심",
    "expiryDays": 3
  },
  {
    "name": "식빵",
    "expiryDays": 7
  }
]
```

## Tenth Baseline Raw Log

```json
{
  "requestId": "0097D82F-2CAE-45EC-8A57-35196AD161C8",
  "experiment": "baseline",
  "model": "gemini-2.5-flash",
  "base64Length": 4100812,
  "serverTotalMs": 7185,
  "geminiMs": 7185,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 4100812,
  "clientImageEncodeMs": 106.31799697875977,
  "clientNetworkRoundTripMs": 11518.931031227112,
  "clientTotalMs": 11643.923997879028,
  "experiment": "baseline",
  "geminiMs": 7185,
  "imageBytes": 3075607,
  "itemsCount": 2,
  "jpegQuality": 0.8,
  "model": "gemini-2.5-flash",
  "requestId": "0097D82F-2CAE-45EC-8A57-35196AD161C8",
  "retryAttempt": 0,
  "serverTotalMs": 7185,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "돼지고기",
    "expiryDays": 4
  },
  {
    "name": "식빵",
    "expiryDays": 7
  }
]
```

## First Image Resize Raw Log

```json
{
  "requestId": "20AD4B47-0783-4586-8348-A358BB4FFFC4",
  "experiment": "image_resize",
  "model": "gemini-2.5-flash",
  "base64Length": 478424,
  "serverTotalMs": 5985,
  "geminiMs": 5985,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 478424,
  "clientImageEncodeMs": 332.0200443267822,
  "clientNetworkRoundTripMs": 7215.083003044128,
  "clientTotalMs": 7591.6420221328735,
  "experiment": "image_resize",
  "geminiMs": 5985,
  "imageBytes": 358818,
  "imageMaxDimension": 1280,
  "itemsCount": 3,
  "jpegQuality": 0.65,
  "model": "gemini-2.5-flash",
  "requestId": "20AD4B47-0783-4586-8348-A358BB4FFFC4",
  "retryAttempt": 0,
  "serverTotalMs": 5985,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "라이스페이퍼",
    "expiryDays": 365
  },
  {
    "name": "찹쌀호떡믹스",
    "expiryDays": 365
  },
  {
    "name": "소면",
    "expiryDays": 365
  }
]
```

## Second Image Resize Raw Log

```json
{
  "requestId": "C04D6898-AC6E-404C-9526-AA7F99F458DF",
  "experiment": "image_resize",
  "model": "gemini-2.5-flash",
  "base64Length": 478424,
  "serverTotalMs": 8345,
  "geminiMs": 8345,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 478424,
  "clientImageEncodeMs": 112.36095428466797,
  "clientNetworkRoundTripMs": 9310.894966125488,
  "clientTotalMs": 9430.667042732239,
  "experiment": "image_resize",
  "geminiMs": 8345,
  "imageBytes": 358818,
  "imageMaxDimension": 1280,
  "itemsCount": 3,
  "jpegQuality": 0.65,
  "model": "gemini-2.5-flash",
  "requestId": "C04D6898-AC6E-404C-9526-AA7F99F458DF",
  "retryAttempt": 0,
  "serverTotalMs": 8345,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "찹쌀호떡믹스",
    "expiryDays": 540
  },
  {
    "name": "라이스페이퍼",
    "expiryDays": 730
  },
  {
    "name": "소면",
    "expiryDays": 900
  }
]
```

## Third Image Resize Raw Log

```json
{
  "requestId": "EFFE694C-7C06-40CB-9AD1-5F7FECC521BA",
  "experiment": "image_resize",
  "model": "gemini-2.5-flash",
  "base64Length": 542744,
  "serverTotalMs": 9447,
  "geminiMs": 9447,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 542744,
  "clientImageEncodeMs": 119.94397640228271,
  "clientNetworkRoundTripMs": 10772.203922271729,
  "clientTotalMs": 10935.855031013489,
  "experiment": "image_resize",
  "geminiMs": 9447,
  "imageBytes": 407058,
  "imageMaxDimension": 1280,
  "itemsCount": 4,
  "jpegQuality": 0.65,
  "model": "gemini-2.5-flash",
  "requestId": "EFFE694C-7C06-40CB-9AD1-5F7FECC521BA",
  "retryAttempt": 0,
  "serverTotalMs": 9447,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "버터",
    "expiryDays": 60
  },
  {
    "name": "팽이버섯",
    "expiryDays": 7
  },
  {
    "name": "펩시 제로 슈거",
    "expiryDays": 7
  },
  {
    "name": "올리브 오일",
    "expiryDays": 180
  }
]
```

## Fourth Image Resize Raw Log

```json
{
  "requestId": "2190C2ED-03EE-41C6-AB83-C9B16C16BD80",
  "experiment": "image_resize",
  "model": "gemini-2.5-flash",
  "base64Length": 542744,
  "serverTotalMs": 7589,
  "geminiMs": 7589,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 542744,
  "clientImageEncodeMs": 120.78094482421875,
  "clientNetworkRoundTripMs": 8659.908056259155,
  "clientTotalMs": 8786.5070104599,
  "experiment": "image_resize",
  "geminiMs": 7589,
  "imageBytes": 407058,
  "imageMaxDimension": 1280,
  "itemsCount": 4,
  "jpegQuality": 0.65,
  "model": "gemini-2.5-flash",
  "requestId": "2190C2ED-03EE-41C6-AB83-C9B16C16BD80",
  "retryAttempt": 0,
  "serverTotalMs": 7589,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "팽이버섯",
    "expiryDays": 7
  },
  {
    "name": "버터",
    "expiryDays": 90
  },
  {
    "name": "펩시 제로 슈거",
    "expiryDays": 180
  },
  {
    "name": "올리브 오일",
    "expiryDays": 365
  }
]
```

## Fifth Image Resize Raw Log

```json
{
  "requestId": "02884A96-01D7-4443-9A10-B2D6D0DF91DF",
  "experiment": "image_resize",
  "model": "gemini-2.5-flash",
  "base64Length": 545424,
  "serverTotalMs": 13411,
  "geminiMs": 13411,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 545424,
  "clientImageEncodeMs": 118.66402626037598,
  "clientNetworkRoundTripMs": 14594.12407875061,
  "clientTotalMs": 14756.12497329712,
  "experiment": "image_resize",
  "geminiMs": 13411,
  "imageBytes": 409068,
  "imageMaxDimension": 1280,
  "itemsCount": 4,
  "jpegQuality": 0.65,
  "model": "gemini-2.5-flash",
  "requestId": "02884A96-01D7-4443-9A10-B2D6D0DF91DF",
  "retryAttempt": 0,
  "serverTotalMs": 13411,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "꼬깔콘",
    "expiryDays": 180
  },
  {
    "name": "고추장",
    "expiryDays": 270
  },
  {
    "name": "와사비 페이스트",
    "expiryDays": 60
  },
  {
    "name": "츄파춥스 말랑말랑 판다",
    "expiryDays": 365
  }
]
```

## Sixth Image Resize Raw Log

```json
{
  "requestId": "0A15C898-0B37-41E2-9DBD-6CEAA0E24368",
  "experiment": "image_resize",
  "model": "gemini-2.5-flash",
  "base64Length": 545424,
  "serverTotalMs": 9431,
  "geminiMs": 9431,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 545424,
  "clientImageEncodeMs": 186.71393394470215,
  "clientNetworkRoundTripMs": 10417.00291633606,
  "clientTotalMs": 10613.65294456482,
  "experiment": "image_resize",
  "geminiMs": 9431,
  "imageBytes": 409068,
  "imageMaxDimension": 1280,
  "itemsCount": 4,
  "jpegQuality": 0.65,
  "model": "gemini-2.5-flash",
  "requestId": "0A15C898-0B37-41E2-9DBD-6CEAA0E24368",
  "retryAttempt": 0,
  "serverTotalMs": 9431,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "고래밥 (스낵)",
    "expiryDays": 120
  },
  {
    "name": "고추장",
    "expiryDays": 180
  },
  {
    "name": "와사비 페이스트",
    "expiryDays": 90
  },
  {
    "name": "츄파춥스 플러피 팬더 (젤리)",
    "expiryDays": 365
  }
]
```

## Seventh Image Resize Raw Log

```json
{
  "requestId": "32F7533E-1922-4135-AE9A-9A0FC228D2D6",
  "experiment": "image_resize",
  "model": "gemini-2.5-flash",
  "base64Length": 484672,
  "serverTotalMs": 9904,
  "geminiMs": 9904,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 484672,
  "clientImageEncodeMs": 148.86999130249023,
  "clientNetworkRoundTripMs": 12761.014938354492,
  "clientTotalMs": 12987.583994865417,
  "experiment": "image_resize",
  "geminiMs": 9904,
  "imageBytes": 363503,
  "imageMaxDimension": 1280,
  "itemsCount": 8,
  "jpegQuality": 0.65,
  "model": "gemini-2.5-flash",
  "requestId": "32F7533E-1922-4135-AE9A-9A0FC228D2D6",
  "retryAttempt": 0,
  "serverTotalMs": 9904,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "양파",
    "expiryDays": 30
  },
  {
    "name": "닭고기",
    "expiryDays": 2
  },
  {
    "name": "마",
    "expiryDays": 10
  },
  {
    "name": "맛술",
    "expiryDays": 180
  },
  {
    "name": "계란",
    "expiryDays": 21
  },
  {
    "name": "즉석밥",
    "expiryDays": 180
  },
  {
    "name": "우유",
    "expiryDays": 7
  },
  {
    "name": "훈제 오리 슬라이스",
    "expiryDays": 14
  }
]
```

## Eighth Image Resize Raw Log

```json
{
  "requestId": "4B72AF46-D89E-4B83-9F85-66B5BA038168",
  "experiment": "image_resize",
  "model": "gemini-2.5-flash",
  "base64Length": 484672,
  "serverTotalMs": 6827,
  "geminiMs": 6827,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 484672,
  "clientImageEncodeMs": 128.19790840148926,
  "clientNetworkRoundTripMs": 7916.23592376709,
  "clientTotalMs": 13788.95902633667,
  "experiment": "image_resize",
  "geminiMs": 6827,
  "imageBytes": 363503,
  "imageMaxDimension": 1280,
  "itemsCount": 8,
  "jpegQuality": 0.65,
  "model": "gemini-2.5-flash",
  "requestId": "4B72AF46-D89E-4B83-9F85-66B5BA038168",
  "retryAttempt": 2,
  "serverTotalMs": 6827,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "양파",
    "expiryDays": 30
  },
  {
    "name": "생닭고기",
    "expiryDays": 2
  },
  {
    "name": "마",
    "expiryDays": 14
  },
  {
    "name": "계란",
    "expiryDays": 21
  },
  {
    "name": "맛술",
    "expiryDays": 180
  },
  {
    "name": "즉석밥",
    "expiryDays": 180
  },
  {
    "name": "오리훈제 슬라이스",
    "expiryDays": 30
  },
  {
    "name": "우유",
    "expiryDays": 7
  }
]
```

## Ninth Image Resize Raw Log

```json
{
  "requestId": "D84F94EB-6064-49DC-8108-6ED1D5910DEA",
  "experiment": "image_resize",
  "model": "gemini-2.5-flash",
  "base64Length": 464352,
  "serverTotalMs": 5202,
  "geminiMs": 5202,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 464352,
  "clientImageEncodeMs": 128.00300121307373,
  "clientNetworkRoundTripMs": 6628.239989280701,
  "clientTotalMs": 6816.707015037537,
  "experiment": "image_resize",
  "geminiMs": 5202,
  "imageBytes": 348264,
  "imageMaxDimension": 1280,
  "itemsCount": 3,
  "jpegQuality": 0.65,
  "model": "gemini-2.5-flash",
  "requestId": "D84F94EB-6064-49DC-8108-6ED1D5910DEA",
  "retryAttempt": 0,
  "serverTotalMs": 5202,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "돼지고기 목살",
    "expiryDays": 4
  },
  {
    "name": "식빵",
    "expiryDays": 6
  },
  {
    "name": "돼지고기 등심",
    "expiryDays": 4
  }
]
```

## Tenth Image Resize Raw Log

```json
{
  "requestId": "EF69E708-08A5-4276-858D-25D2D5FC4C5B",
  "experiment": "image_resize",
  "model": "gemini-2.5-flash",
  "base64Length": 464352,
  "serverTotalMs": 4487,
  "geminiMs": 4487,
  "itemsCount": null,
  "success": true
}
```

```json
{
  "base64Length": 464352,
  "clientImageEncodeMs": 126.56700611114502,
  "clientNetworkRoundTripMs": 5170.837044715881,
  "clientTotalMs": 5307.633996009827,
  "experiment": "image_resize",
  "geminiMs": 4487,
  "imageBytes": 348264,
  "imageMaxDimension": 1280,
  "itemsCount": 3,
  "jpegQuality": 0.65,
  "model": "gemini-2.5-flash",
  "requestId": "EF69E708-08A5-4276-858D-25D2D5FC4C5B",
  "retryAttempt": 0,
  "serverTotalMs": 4487,
  "success": true
}
```

Detected result:

```json
[
  {
    "name": "돼지고기 (앞다리살)",
    "expiryDays": 4
  },
  {
    "name": "돼지고기",
    "expiryDays": 4
  },
  {
    "name": "식빵",
    "expiryDays": 7
  }
]
```
