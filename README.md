# Project 1 — Customer Segmentation & Retention Analysis
### E-Commerce | SQL | MySQL | Olist Dataset

---

## Business Problem

A mid-sized Brazilian e-commerce company has two years of transaction data but no structured way to understand customer behaviour. The Head of Growth needs to know: **who are our best customers, who is slipping away, and where should we focus retention spend?**

Without this visibility, marketing budget is being spread equally across customers who have already churned, customers who are about to churn, and the small group of high-value loyalists who deserve preferential treatment.

---

## Dataset

**Source:** [Olist Brazilian E-Commerce Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — Kaggle (public)

**Tables used:**

| Table | Rows | Purpose |
|---|---|---|
| olist_orders_dataset | 99,441 | Order dates, status, delivery timestamps |
| olist_order_items_dataset | 112,650 | Price and product per order |
| olist_customers_dataset | 99,441 | Customer identifiers |
| olist_order_reviews_dataset | 279 | Review scores (limited coverage) |
| olist_products_dataset | 32,340 | Product categories |

**Date range:** September 2016 – October 2018 (773 days)
**Scope:** Filtered to `delivered` orders only (97.02% of total)

---

## Methodology

Analysis was structured across five phases:

**Phase 1 — Data Exploration & Quality Check**
Validated row counts, null values, date ranges, order status distribution, and join integrity across all five tables before any analysis began. No critical nulls were found. 775 orders with no line items and 1,604 items with no matching product were identified and excluded from downstream analysis.

**Phase 2 — Customer Behaviour Metrics**
Built foundational per-customer metrics including total orders, total spend, average order value, first and last purchase dates, and inter-purchase intervals using window functions. Review score data was assessed and excluded due to less than 0.3% customer coverage — insufficient for statistically reliable conclusions.

**Phase 3 — RFM Segmentation**
Customers were scored on Recency, Frequency, and Monetary dimensions using NTILE(5) window functions, then labelled into six actionable segments. Same-day multi-item orders were deduplicated at the date level to avoid inflating frequency scores.

**Phase 4 — Churn Analysis**
Churn was defined as no purchase in 180 days from the reference date (2018-10-18). Churn rates were measured overall, by product category, and correlated against delivery delay performance using `DATEDIFF` between estimated and actual delivery dates.

**Phase 5 — Stakeholder Summary**
All dimensions — RFM segment, churn status, and delivery bucket — were combined into a single reusable view (`vw_customer_summary`) for ongoing reporting and stakeholder access.

---

## Key Findings

### 1. 90% of the customer base has churned or is at risk of churning

| Status | Customers | % of Total |
|---|---|---|
| 🔴 Churned (180+ days inactive) | 66,152 | 70.86% |
| 🟡 At Risk (90–180 days inactive) | 18,336 | 19.64% |
| 🟢 Active (< 90 days) | 8,870 | 9.50% |

Only 1 in 10 customers is genuinely active. The business is running on acquisition alone with almost no retention engine in place.

### 2. Late deliveries directly drive churn — a 21 percentage point gap

| Delivery Performance | Customers | Churn Rate |
|---|---|---|
| ✅ On time or early | 87,041 | 70.1% |
| 🟡 Slightly late (1–7 days) | 3,559 | 76.3% |
| 🟠 Late (8–14 days) | 1,425 | 84.4% |
| 🔴 Very late (15+ days) | 1,333 | 91.4% |

Every tier of delivery lateness increases churn by approximately 7 percentage points. Customers who experienced very late deliveries churn at 91.4% — 21 points higher than on-time customers. This is a clear, linear, actionable relationship.

### 3. The At Risk segment represents 40% of all revenue

| Segment | Customers | % of Customers | Total Revenue (R$) | Avg Value (R$) | % of Revenue |
|---|---|---|---|---|---|
| ⚠️ At Risk | 37,344 | 40.00% | 6,175,166 | 165 | 40.05% |
| 🌱 Promising | 30,085 | 32.23% | 4,960,433 | 165 | 32.17% |
| 🔄 Loyal | 17,788 | 19.05% | 2,839,938 | 160 | 18.42% |
| 👋 Lost | 7,259 | 7.78% | 1,114,140 | 153 | 7.23% |
| 🏆 Champion | 882 | 0.94% | 330,097 | 374 | 2.14% |

Champions are worth 2.3x the average customer (R$374 vs R$165) but represent less than 1% of the base. At Risk customers are the single largest revenue group and are actively disengaging.

### 4. Fashion categories show the highest churn rates (84–88%)

Fashion underwear, footwear, and menswear lead churn at 84–88% — driven by high competition and impulse purchase behaviour in these categories. High-volume categories like `cool_stuff` (3,543 customers, 84% churn) and `brinquedos` (toys, 3,763 customers, 80% churn) represent large audiences that buy once and don't return.

---

## Recommendations

### 1. Launch a targeted re-engagement campaign for the At Risk segment
37,344 customers representing 40% of total revenue are slipping away. These customers have purchase history and brand familiarity — re-engagement cost is significantly lower than new customer acquisition. A time-limited discount or personalised product recommendation campaign targeted specifically at this group should be the immediate priority.

### 2. Nurture the Promising segment before they disengage
30,085 recently active customers with no repeat purchase yet. This is the lowest-cost conversion opportunity in the entire base. A follow-up email sequence or loyalty incentive triggered 30–60 days after first purchase could materially increase the repeat purchase rate from this group.

### 3. Fix logistics before any other marketing investment
6,317 customers received late deliveries and churn at up to 91.4%. Investing in marketing to acquire or retain customers while the delivery experience remains broken is a leaky bucket strategy. Reducing average delivery delay in the 8–14 day and 15+ day buckets should be treated as a prerequisite to retention spend, not a separate operational issue.

### 4. Build a VIP programme for Champions
Only 882 Champions exist in the entire customer base, but they spend 2.3x the average customer. This group should be identified, tracked, and treated distinctly — early access, dedicated support, or loyalty rewards. Losing a Champion is disproportionately costly compared to losing an average customer.

---

## Methodology Note on Review Scores

Review score data was assessed in Phase 2 and covered fewer than 0.3% of customers (270 out of 96,000+). Drawing churn correlations from this sample would produce statistically unreliable conclusions. Delivery performance data was used instead, with 96%+ customer coverage, providing a far more robust basis for the churn correlation analysis in Phase 4.

---

## Repository Structure

```
project-1-customer-segmentation/
│
├── README.md
│
├── phase1_exploration/
│   ├── q1_null_check.sql
│   ├── q2_date_range_status.sql
│   └── q3_join_integrity.sql
│
├── phase2_metrics/
│   ├── q4_customer_lifetime_metrics.sql
│   ├── q5_days_between_purchases.sql
│   └── q6_review_scores.sql
│
├── phase3_rfm/
│   ├── q7_rfm_raw.sql
│   ├── q8_rfm_scoring.sql
│   ├── q9_segment_labels.sql
│   └── q9b_segment_summary.sql
│
├── phase4_churn/
│   ├── q10_churn_flag.sql
│   ├── q10b_churn_summary.sql
│   ├── q11_churn_by_category.sql
│   └── q12_delivery_vs_churn.sql
│
└── phase5_output/
    ├── q13_create_view.sql
    └── q14_priority_action_table.sql
```

---

## How to Run

1. Download the Olist dataset from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
2. Import the five required tables into MySQL (geolocation table not required)
3. Ensure your database uses `utf8mb4` character set for emoji label support:
   ```sql
   ALTER DATABASE your_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```
4. Run queries in phase order — each phase builds on the previous
5. Create the summary view last (`q13_create_view.sql`) before running `q14`

**MySQL version tested:** 8.0+

---

*Analysis by [Your Name] | [LinkedIn] | [Portfolio URL]*
