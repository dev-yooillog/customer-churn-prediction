# 통신사 고객 이탈 분석 및 ML 기반 예측
### Telco Customer Churn Analysis & Prediction Pipeline

> 통신사 고객 데이터에서 이탈 패턴을 SQL로 탐색하고, 머신러닝 모델로 조기 이탈 가능 고객을 예측하는 엔드투엔드 파이프라인 구축

| 항목 | 내용 |
|------|------|
| 개발 기간 | 3주 |
| 개발 인원 | 1인 (기여도 100%) |
| 데이터 | WA_Fn-UseC_-Telco-Customer-Churn (7,043 rows, 21 columns) |
| 기술 스택 | MySQL, Python, scikit-learn, XGBoost, imbalanced-learn |

---
#### Background / Objective
통신사 고객 데이터에서 고객 이탈 패턴과 위험 요인을 파악하고, 머신러닝 모델을 통해 조기 이탈 가능 고객을 예측하는 것이 목표였습니다.

- SQL 탐색 분석으로 계약 유형·요금제·결제 방식·서비스 가입 여부별 이탈률 확인
- Python 기반 ML 모델로 고객 세그멘테이션 및 예측 모델 성능 검증

---

## 문제 상황

통신사는 신규 고객 유치 비용이 기존 고객 유지 비용보다 5~7배 높다.
고객 이탈이 발생한 이후에는 대응이 어렵기 때문에, **이탈 전 조기 식별 및 선제적 개입**이 핵심이다.
본 프로젝트는 SQL 기반 탐색 분석으로 이탈 패턴을 파악하고, ML 모델로 이탈 위험 고객을 사전에 예측하는 것을 목표로 한다.

---

## 기술 스택

| 분류 | 도구 |
|------|------|
| 데이터베이스 | MySQL 8.0 |
| 분석 언어 | Python 3.10 |
| 데이터 처리 | pandas, NumPy |
| 시각화 | matplotlib, seaborn |
| 머신러닝 | scikit-learn, XGBoost, imbalanced-learn (SMOTE) |
| 개발 환경 | Jupyter Notebook, VS Code |

---

## 1. 시스템 아키텍처

```
Raw CSV Data
     │
     ▼
┌─────────────────────────────────────────┐
│              MySQL (telco_db)           │
│  01_setup.sql : CREATE TABLE + INSERT   │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┴──────────┐
        ▼                    ▼
┌──────────────┐    ┌─────────────────────┐
│ 02_eda_      │    │ 03_advanced_        │
│ queries.sql  │    │ queries.sql         │
│              │    │                     │
│ 기초 EDA     │    │ CTE / Window Func   │
│ 이탈률 분석  │    │ 위험 스코어링       │
│ 세그멘테이션 │    │ LTV 손실 추정       │
└──────────────┘    └─────────────────────┘
        │
        ▼
┌─────────────────────────────────────────┐
│     churn_prediction_ml_pipeline.ipynb  │
│                                         │
│  전처리 → SMOTE → 모델 학습 → 평가     │
│  LR / RF / XGBoost / Ensemble           │
└─────────────────────────────────────────┘
        │
        ▼
   비즈니스 인사이트 & 액션 아이템
```

---

## 2. 프로세스 플로우

```
[1] 데이터 수집 & DB 구축
    └─ CSV 로드 → MySQL 테이블 생성 → 7,043행 INSERT

[2] SQL 탐색 분석 (EDA)
    └─ 계약 유형 / 결제 방식 / 서비스 가입 여부 / 연령대별 이탈률 분석
    └─ 조기 이탈 고객 식별 (tenure ≤ 6, MonthlyCharges > 70)
    └─ 고객 세그멘테이션 (VIP / 이탈위험 / 업셀링 / 일반)

[3] SQL 심화 분석
    └─ CTE 기반 위험 스코어링 (가중치 합산)
    └─ Window Function : 누적 이탈, 요금 분위 순위
    └─ 다단계 CTE : LTV 추정 및 이탈 손실액 계산

[4] Python ML 파이프라인
    └─ 전처리 : OneHotEncoding, StandardScaler, SimpleImputer
    └─ 불균형 처리 : SMOTE (0:4139 → 0:4139 / 1:1495 → 1:4139)
    └─ 모델 학습 : LR / RF / XGBoost
    └─ 튜닝 : GridSearchCV (Random Forest)
    └─ 앙상블 : VotingClassifier (RF + XGBoost + GB)

[5] 결과 해석 & 액션 아이템 도출
    └─ Feature Importance 분석
    └─ 비즈니스 전략 연결
```

---

## 3. 핵심 인사이트

**① Month-to-month 계약 고객 이탈률이 장기 계약 대비 3배 이상 높음**
- Month-to-month: ~42% / One year: ~11% / Two year: ~3%
- 단기 계약 고객의 Lock-in 전략이 가장 시급한 과제

**② 가입 초기 6개월 이내 이탈이 전체 이탈의 핵심 구간**
- tenure ≤ 6개월 구간 이탈률이 전체 평균(26.54%) 대비 현저히 높음
- 온보딩 경험 개선과 초기 프로모션이 이탈 방지에 직결

**③ 추가 서비스 번들 가입 수가 많을수록 이탈률 감소**
- 서비스 0개: 이탈률 ~37% / 서비스 5~6개: 이탈률 ~20% 수준
- 온보딩 시 번들 제안이 장기 유지율 향상에 효과적

---

## 4. ML 모델 성능

| 모델 | Accuracy | Precision | Recall | F1 | AUC |
|------|----------|-----------|--------|----|-----|
| Logistic Regression | 0.8055 | - | - | 0.6040 | 0.8419 |
| Random Forest | 0.7779 | - | - | 0.5321 | 0.8164 |
| XGBoost | 0.7736 | - | - | 0.5384 | 0.8217 |
| Optimized Random Forest | - | - | - | 향상 | - |
| Ensemble (Voting) | - | - | - | 0.5997 | 0.8338 |

- 최종 채택 모델: **Gradient Boosting (AUC 0.8432)**
- 주요 피처: MonthlyCharges, tenure, Contract, TotalCharges

---

## 5. 예상 임팩트

| 항목 | 내용 |
|------|------|
| 이탈 위험 고객 조기 식별 | 매월 고위험군 추출 → CRM 연동으로 선제 대응 가능 |
| Lock-in 전략 | Month-to-month → 1년 계약 전환 시 이탈률 약 30%p 감소 예상 |
| 번들 판매 효과 | 서비스 추가 가입 유도로 이탈률 최대 17%p 감소 가능 |
| LTV 손실 방지 | Month-to-month 이탈 손실이 전체의 약 60% 이상 차지 → 집중 관리 필요 |

---

## 6. 성과 및 피드백

### 정량적 성과
- SQL 9개 탐색 쿼리 + 심화 쿼리 7개 (CTE, Window Function, 스코어링) 구현
- ML 모델 5종 비교 → AUC 0.84 수준 달성
- SMOTE로 클래스 불균형 해소 (이탈:비이탈 = 1:2.8 → 1:1)

### 정성적 성과
- SQL EDA → ML 파이프라인 → 비즈니스 인사이트까지 엔드투엔드 구현 경험
- 이탈 레이블 없이 행동 패턴만으로 위험군을 식별하는 실무형 세그멘테이션 설계

### 향후 개선 사항
- SHAP 값 기반 개별 고객 이탈 원인 설명 추가
- 실시간 스코어링 API 연동 (FastAPI)
- 시계열 데이터 확보 시 월별 이탈 예측 모델로 확장

---

## 7. 파일 구조

```
telco-churn-project/
│
├── 01_setup.sql                      # DB 생성 + 테이블 + 데이터 INSERT
├── 02_eda_queries.sql                # SQL 기초 탐색 분석 (9개 쿼리)
├── 03_advanced_queries.sql           # SQL 심화 분석 (CTE, Window Function)
├── churn_prediction_ml_pipeline.ipynb  # ML 파이프라인 (전처리 ~ 앙상블)
├── WA_Fn-UseC_-Telco-Customer-Churn.csv
└── README.md
```

---

## 8. 실행 방법

**DB 세팅**
```bash
mysql -u root -p < 01_setup.sql
```

**SQL 분석 실행**
```bash
mysql -u root -p telco_db < 02_eda_queries.sql
mysql -u root -p telco_db < 03_advanced_queries.sql
```

**Python 환경 설치**
```bash
pip install pandas numpy matplotlib seaborn scikit-learn xgboost imbalanced-learn
```

**노트북 실행**
```bash
jupyter notebook churn_prediction_ml_pipeline.ipynb
```
