USE telco_db;

-- [SECTION 1] 집계 & 필터링


-- 1-1. 전체 고객 수 및 이탈률 요약
SELECT
    COUNT(*)                                                              AS total_customers,
    SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END)                       AS churned,
    ROUND(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                                  AS churn_rate_pct
FROM customers;

-- 1-2. 계약 유형 × 결제 방식 교차 이탈률
SELECT
    Contract,
    PaymentMethod,
    COUNT(*)                                                              AS total,
    SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END)                       AS churned,
    ROUND(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                                  AS churn_rate_pct
FROM customers
GROUP BY Contract, PaymentMethod
ORDER BY churn_rate_pct DESC;

-- 1-3. 조기 이탈 고객 프로파일
SELECT
    customerID,
    Contract,
    tenure,
    MonthlyCharges,
    PaymentMethod,
    InternetService
FROM customers
WHERE tenure      <= 6
  AND MonthlyCharges > 70
  AND Churn        = 'Yes'
ORDER BY MonthlyCharges DESC;

-- [SECTION 2] 중급 : 서브쿼리 & CASE

-- 2-1. 고객 세그먼트 분류 (Churn 레이블 미사용 → 실무 적용 가능)
--      VIP / 이탈위험 / 업셀링 / 일반
SELECT
    customer_segment,
    COUNT(*)                                                              AS total,
    SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END)                       AS actual_churned,
    ROUND(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                                  AS churn_rate_pct
FROM (
    SELECT Churn,
        CASE
            WHEN tenure > 24 AND MonthlyCharges > 70 THEN 'VIP 고객'
            WHEN tenure <= 6 AND MonthlyCharges > 70 THEN '이탈 위험 고객'
            WHEN tenure > 24 AND MonthlyCharges < 30 THEN '업셀링 가능 고객'
            ELSE '일반 고객'
        END AS customer_segment
    FROM customers
) seg
GROUP BY customer_segment
ORDER BY churn_rate_pct DESC;

-- 2-2. 서비스 번들 수와 이탈률의 관계
--      가입 서비스가 많을수록 이탈률이 낮아지는지 검증
SELECT service_count,
    COUNT(*)                                                              AS total,
    SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END)                       AS churned,
    ROUND(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                                  AS churn_rate_pct
FROM (
    SELECT
        Churn,
        (
            (CASE WHEN OnlineSecurity  = 'Yes' THEN 1 ELSE 0 END) +
            (CASE WHEN OnlineBackup    = 'Yes' THEN 1 ELSE 0 END) +
            (CASE WHEN DeviceProtection= 'Yes' THEN 1 ELSE 0 END) +
            (CASE WHEN TechSupport     = 'Yes' THEN 1 ELSE 0 END) +
            (CASE WHEN StreamingTV     = 'Yes' THEN 1 ELSE 0 END) +
            (CASE WHEN StreamingMovies = 'Yes' THEN 1 ELSE 0 END)
        ) AS service_count
    FROM customers
    WHERE InternetService != 'No'
) sc
GROUP BY service_count
ORDER BY service_count;

-- 2-3. 전체 평균 대비 고요금 이탈 고객 비율
SELECT
    ROUND(AVG(MonthlyCharges), 2)                                         AS avg_monthly_all,
    SUM(CASE
            WHEN Churn = 'Yes'
             AND MonthlyCharges > (SELECT AVG(MonthlyCharges) FROM customers)
            THEN 1 ELSE 0
        END)                                                              AS high_charge_churned,
    ROUND(100.0 *
          SUM(CASE
                  WHEN Churn = 'Yes'
                   AND MonthlyCharges > (SELECT AVG(MonthlyCharges) FROM customers)
                  THEN 1 ELSE 0
              END)
          / SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END), 2)           AS pct_of_all_churned
FROM customers;

-- [SECTION 3] 심화 : CTE & Window Function
-- 3-1. 이탈 위험 고객 식별 → 즉시 활용 가능한 타겟 리스트
WITH risk_customers AS (
    SELECT
        customerID,
        Contract,
        tenure,
        MonthlyCharges,
        PaymentMethod,
        InternetService,
        -- 위험 점수 : 조건별 가중치 합산
        (
            CASE WHEN Contract       = 'Month-to-month'           THEN 3 ELSE 0 END +
            CASE WHEN tenure         <= 6                          THEN 2 ELSE 0 END +
            CASE WHEN MonthlyCharges > 70                          THEN 2 ELSE 0 END +
            CASE WHEN PaymentMethod  = 'Electronic check'          THEN 1 ELSE 0 END +
            CASE WHEN InternetService = 'Fiber optic'              THEN 1 ELSE 0 END
        ) AS risk_score
    FROM customers
    WHERE Churn = 'No'   -- 아직 이탈하지 않은 고객만 대상
)
SELECT
    customerID,
    Contract,
    tenure,
    MonthlyCharges,
    PaymentMethod,
    risk_score,
    CASE
        WHEN risk_score >= 7 THEN '즉시 개입 필요'
        WHEN risk_score >= 4 THEN '모니터링 대상'
        ELSE '안정 고객'
    END AS action_label
FROM risk_customers
ORDER BY risk_score DESC
LIMIT 30;

-- 3-2. tenure 구간별 이탈률 + 누적 이탈 고객 수
WITH tenure_bucket AS (
    SELECT
        CASE
            WHEN tenure BETWEEN  0 AND  6  THEN '0-6개월'
            WHEN tenure BETWEEN  7 AND 12  THEN '7-12개월'
            WHEN tenure BETWEEN 13 AND 24  THEN '13-24개월'
            WHEN tenure BETWEEN 25 AND 48  THEN '25-48개월'
            ELSE '49개월+'
        END                                                               AS tenure_group,
        CASE
            WHEN tenure BETWEEN  0 AND  6  THEN 1
            WHEN tenure BETWEEN  7 AND 12  THEN 2
            WHEN tenure BETWEEN 13 AND 24  THEN 3
            WHEN tenure BETWEEN 25 AND 48  THEN 4
            ELSE 5
        END                                                               AS grp_order,
        Churn
    FROM customers
)
SELECT
    tenure_group,
    COUNT(*)                                                              AS total,
    SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END)                       AS churned,
    ROUND(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                                  AS churn_rate_pct,
    -- 누적 이탈 고객 수 (Window Function)
    SUM(SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END))
        OVER (ORDER BY grp_order
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)          AS cumulative_churned
FROM tenure_bucket
GROUP BY tenure_group, grp_order
ORDER BY grp_order;

-- 3-3. 결제 방식 내 MonthlyCharges 순위 + 이탈 여부
--      동일 결제 방식 내에서 고요금일수록 이탈 비율이 높은지 확인
SELECT
    customerID,
    PaymentMethod,
    MonthlyCharges,
    Churn,
    RANK()       OVER (PARTITION BY PaymentMethod ORDER BY MonthlyCharges DESC) AS charge_rank,
    NTILE(4)     OVER (PARTITION BY PaymentMethod ORDER BY MonthlyCharges DESC) AS charge_quartile,
    ROUND(AVG(MonthlyCharges) OVER (PARTITION BY PaymentMethod), 2)             AS avg_charge_in_payment
FROM customers
ORDER BY PaymentMethod, charge_rank
LIMIT 50;

-- 3-4. 다단계 : 계약 유형별 LTV 추정 및 이탈 손실 계산
WITH customer_ltv AS (
    SELECT
        customerID,
        Contract,
        Churn,
        MonthlyCharges,
        tenure,
        TotalCharges,
        -- 계약 유형별 평균 tenure 기반 잔여 기간 추정
        CASE
            WHEN Contract = 'Month-to-month' THEN GREATEST(0, 12  - tenure)
            WHEN Contract = 'One year'       THEN GREATEST(0, 24  - tenure)
            WHEN Contract = 'Two year'       THEN GREATEST(0, 48  - tenure)
        END                                                               AS remaining_months,
        MonthlyCharges *
        CASE
            WHEN Contract = 'Month-to-month' THEN GREATEST(0, 12  - tenure)
            WHEN Contract = 'One year'       THEN GREATEST(0, 24  - tenure)
            WHEN Contract = 'Two year'       THEN GREATEST(0, 48  - tenure)
        END                                                               AS estimated_ltv
    FROM customers
),
ltv_summary AS (
    SELECT
        Contract,
        COUNT(*)                                                          AS total,
        SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END)                   AS churned,
        ROUND(AVG(estimated_ltv), 2)                                      AS avg_ltv,
        -- 이탈로 인한 추정 손실액
        ROUND(SUM(CASE WHEN Churn = 'Yes' THEN estimated_ltv ELSE 0 END), 2) AS lost_ltv
    FROM customer_ltv
    GROUP BY Contract
)
SELECT
    Contract,
    total,
    churned,
    avg_ltv,
    lost_ltv,
    -- 전체 손실 중 계약 유형별 비중
    ROUND(100.0 * lost_ltv / SUM(lost_ltv) OVER (), 2)                   AS lost_ltv_share_pct
FROM ltv_summary
ORDER BY lost_ltv DESC;