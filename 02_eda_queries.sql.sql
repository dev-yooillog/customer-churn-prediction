USE telco_db;
-- 현재 secure-file-priv 설정 확인하기
-- SHOW VARIABLES LIKE 'secure_file_priv';

-- 고객 데이터 조회 
SELECT * FROM customers LIMIT 10;

-- (1) 계약 유형별 이탈률 
SELECT Contract, 
       COUNT(*) AS total_customers,
       SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churn_count,
       ROUND(100 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate
FROM customers
GROUP BY Contract
ORDER BY churn_rate DESC;
-- Month-to-month 계약 고객이 이탈률이 가장 높을 가능성이 크다.
-- 장기 계약(1년, 2년) 고객과 비교 분석 가능

-- (2) 이탈 고객과 유지 고객 분류
SELECT customerID, Contract, MonthlyCharges,
       CASE 
           WHEN Churn = 'Yes' THEN '이탈 고객' 
           ELSE '유지 고객' 
       END AS customer_status
FROM Customers;

-- (3) 요금제별 평균 청구 금액 비교
SELECT Contract, 
       ROUND(AVG(MonthlyCharges), 2) AS avg_monthly_charge,
       ROUND(AVG(TotalCharges), 2) AS avg_total_charge
FROM Customers
GROUP BY Contract
ORDER BY avg_monthly_charge DESC;
-- 고가 요금제 고객 이탈 방지를 위한 전략 필요

-- (4) 조기 이탈 가능성이 높은 고객 찾기
SELECT customerID, Contract, tenure, MonthlyCharges, PaymentMethod, Churn
FROM Customers
WHERE tenure <= 6
  AND MonthlyCharges > 70
  AND Churn = 'Yes';

-- (5) 결재 방법에 따른 이탈률 
SELECT PaymentMethod, 
       COUNT(*) AS total_customers,
       SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churn_count,
       ROUND(100 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate
FROM Customers
GROUP BY PaymentMethod
ORDER BY churn_rate DESC;
 
-- (6) 연령별 이탈률
SELECT 
       CASE 
           WHEN SeniorCitizen = 1 THEN '고령 고객' 
           ELSE '일반 고객' 
       END AS age_group,
       COUNT(*) AS total_customers,
       SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churn_count,
       ROUND(100 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate
FROM Customers
GROUP BY age_group
ORDER BY churn_rate DESC;

-- (7) 인터넷 서비스 유형별 이탈률 비교
SELECT InternetService, 
       COUNT(*) AS total_customers,
       SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
       ROUND(AVG(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) * 100, 2) AS churn_rate
FROM Customers
GROUP BY InternetService
ORDER BY churn_rate DESC;

-- (8) 추가 서비스 가입 여부에 따른 이탈률
-- Online Security, Tech Support, Steaming 서비스 가입여부에 따른 이탈률

--  Online Security 서비스 가입 여부에 따른 이탈률
SELECT OnlineSecurity, 
       COUNT(*) AS total_customers,
       SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churn_count,
       ROUND(100 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate
FROM Customers
WHERE InternetService != 'No'  -- 인터넷 서비스 사용 고객만 대상
GROUP BY OnlineSecurity
ORDER BY churn_rate DESC;

-- Tech Support 서비스 가입 여부에 따른 이탈률
SELECT TechSupport, 
       COUNT(*) AS total_customers,
       SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churn_count,
       ROUND(100 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate
FROM Customers
WHERE InternetService != 'No'  -- 인터넷 서비스 사용 고객만 대상
GROUP BY TechSupport
ORDER BY churn_rate DESC;

-- 스트리밍 서비스 가입 여부에 따른 이탈률
SELECT 
    CASE 
        WHEN StreamingTV = 'Yes' AND StreamingMovies = 'Yes' THEN '모든 스트리밍'
        WHEN StreamingTV = 'Yes' OR StreamingMovies = 'Yes' THEN '일부 스트리밍'
        ELSE '스트리밍 없음'
    END AS streaming_services,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churn_count,
    ROUND(100 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate
FROM Customers
WHERE InternetService != 'No'  -- 인터넷 서비스 사용 고객만 대상
GROUP BY streaming_services
ORDER BY churn_rate DESC;

-- (9) 고객 유형별 세그멘테이션
-- 세그멘테이션은 이탈 레이블 없이 행동 패턴(tenure, MonthlyCharges)만으로 분류해야
-- 실무에서 Churn을 모르는 시점에도 위험군 식별이 가능함
SELECT 
       CASE 
           WHEN tenure > 24 AND MonthlyCharges > 70 THEN 'VIP 고객'
           WHEN tenure <= 6 AND MonthlyCharges > 70 THEN '이탈 위험 고객'
           WHEN tenure > 24 AND MonthlyCharges < 30 THEN '업셀링 가능 고객'
           ELSE '일반 고객'
       END AS customer_segment,
       COUNT(*) AS total_customers
FROM Customers
GROUP BY customer_segment;