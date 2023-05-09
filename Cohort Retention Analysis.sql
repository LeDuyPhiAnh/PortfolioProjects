-- Cohort Retention Analysis

--Tìm giao dịch lần đầu của từng khách hàng và khoảng cách giữa các lần mua sau với lần đầu
WITH customer_list AS
(SELECT customer_id,
        transaction_time,
        MIN(transaction_time) OVER (PARTITION BY customer_id) first_time, --Tìm lần đầu mua hàng
        DATEDIFF(month,MIN(transaction_time) OVER (PARTITION BY customer_id), transaction_time ) subsequent_month --Khoảng cách giữa các lần mua sau với lần đầu (tính bằng tháng)
FROM fact_transaction_2019 fact_19
JOIN dim_scenario scena 
    ON fact_19.scenario_id = scena.scenario_id
JOIN dim_status sta 
    ON fact_19.status_id = sta.status_id
WHERE scena.sub_category = 'Shopping Stores' AND status_description = 'Success')
,



join_month AS
(SELECT MONTH(first_time) acquisition_month,
        subsequent_month,
        COUNT(DISTINCT customer_id) retained_users
FROM customer_list
GROUP BY subsequent_month,MONTH(first_time))



-- calculate  how many users are retained in each subsequent month from each month in 2019

-- TEMP TABLE
SELECT *,
        FIRST_VALUE(retained_users) OVER (PARTITION BY acquisition_month ORDER BY subsequent_month) original_users,
        FORMAT(retained_users*1.0/FIRST_VALUE(retained_users) OVER (PARTITION BY acquisition_month ORDER BY subsequent_month),'p') pct
INTO #retention_cohort_analysis
FROM join_month


SELECT *
FROM #retention_cohort_analysis


--Xóa bảng tạm
DROP TABLE #retention_cohort_analysis




--Pivot Table for visualizations
SELECT acquisition_month, original_users,
   "0","1","2","3","4","5","6","7","8","9","10","11"
FROM
    (
        SELECT acquisition_month, subsequent_month, original_users, pct
        FROM #retention_cohort_analysis
    ) AS source_table
PIVOT (
    MIN(pct)
    FOR subsequent_month in ("0","1","2","3","4","5","6","7","8","9","10","11")
) pivot_table
ORDER BY acquisition_month