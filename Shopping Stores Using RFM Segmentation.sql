--Tính RFM cho từng khách hàng thanh toán thành công ở Shopping Stores


--Gộp 2 năm 2019 + 2020 
WITH fact AS 
(SELECT customer_id,
        transaction_id,
        transaction_time,
        charged_amount *1.0 AS total_amount
FROM
    (SELECT *
    FROM fact_transaction_2019
    UNION
    SELECT *
    FROM fact_transaction_2020) fact_table
JOIN dim_scenario scena 
    ON fact_table.scenario_id = scena.scenario_id
JOIN dim_status sta 
    ON fact_table.status_id = sta.status_id
WHERE sub_category = 'Shopping Stores' AND sta.status_id = 1)
,

--Tính Recency, Frequency và Monetary
rfm_table AS
(SELECT customer_id,
        DATEDIFF(day,MAX(transaction_time),'2020-12-31') AS Recency,
        COUNT (DISTINCT CONVERT(varchar(10),transaction_time)) AS Frequency,
        SUM(total_amount) AS Monetary
FROM fact
GROUP BY customer_id)
,

--Đánh thứ hạng cho R,F,M 
score_table AS
(SELECT *,
        PERCENT_RANK() OVER (ORDER BY Recency ASC) AS R_score, --R càng nhỏ càng tốt, nhỏ là Tier 1
        PERCENT_RANK() OVER (ORDER BY Frequency DESC) AS F_score, --F càng lớn càng tốt, lớn là Tier 1
        PERCENT_RANK() OVER (ORDER BY Monetary DESC) AS M_score --M  càng lớn càng tốt, lớn là Tier 1
FROM rfm_table),
-- => Tier 1 là tier tốt nhất.

--phan loại các tier
tier_table AS
(SELECT *,
    CASE WHEN R_score > 0.75 then 4
        WHEN R_score > 0.5 then 3
        WHEN R_score > 0.25 then 2
        ELSE 1 END AS r_tier,
    CASE WHEN F_score > 0.75 then 4
        WHEN F_score > 0.5 then 3
        WHEN F_score > 0.25 then 2
        ELSE 1 END AS f_tier,
    CASE WHEN M_score > 0.75 then 4
        WHEN M_score > 0.5 then 3
        WHEN M_score > 0.25 then 2
        ELSE 1 END AS m_tier
FROM score_table),
--=> Tier 1 là score từ 0-25% đầu tiên theo quy ước, các tier còn lại chia đều nhau (25%)


--tạo thành rfm_score
rfm_tier AS
(SELECT customer_id,
        Recency,
        Frequency,
        Monetary,
        r_tier,
        f_tier,
        m_tier,
        CONCAT(r_tier,f_tier,m_tier) AS rfm_score
FROM tier_table),


--Phân loại hành vi khách hàng theo RFM
segment_label AS
(SELECT *,
        CASE
    WHEN rfm_score = 111 THEN 'Best Customers'
    WHEN rfm_score LIKE '[3-4][3-4][1-4]' THEN 'Lost Bad Customer' -- KH rời bỏ mà còn siêu tệ (F thấp)
    WHEN rfm_score LIKE '[3-4]2[1-4]' THEN 'Lost Customers' -- KH cũng rời bỏ nhưng từng có valued
    WHEN rfm_score LIKE '21[1-4]' THEN 'Almost Lost' -- sắp lost những KH này
    WHEN rfm_score LIKE '11[2-4]' THEN 'Loyal Customers'
    WHEN rfm_score LIKE '[1-2][1-3]1' THEN 'Big Spenders' --chi nhiều tiền
    WHEN rfm_score LIKE '[1-2]4[1-4]' THEN 'New Customers' -- KH mới, mới chỉ gd ít ngày 
    WHEN rfm_score LIKE '[3-4]1[1-4]' THEN 'Hibernating' -- ngủ đông (quá khứ thì tốt)
    WHEN rfm_score LIKE '[1-2][2-3][2-4]' THEN 'Potential Loyalists'
    ELSE 'unknown'
    END AS segment_label

FROM rfm_tier)

SELECT segment_label,
        COUNT( customer_id) number_customer,
        SUM(COUNT( customer_id)) OVER() total_customer,
        FORMAT(COUNT( customer_id)*1.0/SUM(COUNT( customer_id)) OVER(),'p') AS pct
FROM segment_label
GROUP BY segment_label
ORDER BY COUNT( customer_id) DESC