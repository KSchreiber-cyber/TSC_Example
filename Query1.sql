USE [Payroll_Madrid_2019]
GO
/****** Object:  StoredProcedure [dbo].[A7_ADHOC_QUERIES]    Script Date: 25/06/2019 5:55:08 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[A7_ADHOC_QUERIES] AS


---------------------------------------------------------------------------------------------------------------
-- Create award join 
---------------------------------------------------------------------------------------------------------------

drop table if exists  #Award_Join
select
C.[Applicable Award / EBA]
,C.[Classification level]
,C.[Job Title]
,C.Instrument
,C.Classification
,D.Position
,D.Amount_Value
,D.Condition
INTO #Award_Join
FROM REF_Award_Position_Mapping C
left join REF_EBA_Wages_Allowances D
on C.Instrument = D.Instrument
and C.Classification = D.Position
where D.Position is not null 



---------------------------------------------------------------------------------------------------------------
-- Hourly rate difference by payslip RAW_Employee_Hourly_Rate_Difference
---------------------------------------------------------------------------------------------------------------

drop table if exists  RAW_Employee_Hourly_Rate_Difference

select distinct
A.k_psd_id
,A.k_ps_id
,A.k_emp_id
,A.Employee_ID
,B.Employee_Start_Date
,B.award
,B.level_grade
,B.position
,B.pay_cycle
,A.Pay_Period_From
,A.Pay_Period_To
,A.pay_date
,A.k_days_since_last_ps
,A.k_pay_cycle
,A.Pay_Code
,A.Pay_Code_Description
,A.Amount AS Amount
,A.[Hours] AS Hours
,A.Amount / NULLIF(A.[Hours],0) AS Calcualted_hourly_rate
,E.Amount_Value AS EBA_Hourly_Rate
,(A.Amount / NULLIF(A.[Hours],0)-E.Amount_Value)  AS Hourly_Difference
INTO RAW_Employee_Hourly_Rate_Difference
from FACT_Payslip_Details A
left join FACT_Employees B
on a.Employee_ID = b.Employee_ID
left join #Award_Join E
on B.award=E.[Applicable Award / EBA]
and b.level_grade = E.[Classification level]
--AND A.Amount is not null
WHERE B.award <> 'N/A'
AND A.Amount <> '0'
AND Pay_Code = 'Base Amount'

/*
---------------------------------------------------------------------------------------------------------------
-- hourly rate difference AVG by employee RAW_Employee_Rate_Difference_AVG
---------------------------------------------------------------------------------------------------------------

drop table if exists RAW_Employee_Rate_Difference_AVG

select distinct
--A.k_psd_id
--,A.k_ps_id
--,A.k_emp_id
A.Employee_ID
,B.Employee_Start_Date
,B.[Company_Code]
,B.award
,B.level_grade
,B.position
,min(A.Pay_Period_From) AS Min_Pay_Date
,max(A.Pay_Period_To)AS Max_Pay_Date
,A.Pay_Code
,A.Pay_Code_Description
,SUM(A.Amount) AS Amount
,SUM(A.[Hours]) AS Hours
,SUM(A.Amount) / NULLIF(SUM(A.[Hours]),0) AS Calcualted_hourly_rate
,AVG(E.Amount_Value) AS EBA_Hourly_Rate
,(SUM(A.Amount) / NULLIF(SUM(A.[Hours]),0)-(AVG(E.Amount_Value)))  AS Hourly_Difference
INTO RAW_Employee_Rate_Difference_AVG
from FACT_Payslip_Details A
left join FACT_Employees B
on a.Employee_ID = b.Employee_ID
left join #Award_Join E
on B.award=E.[Applicable Award / EBA]
and b.level_grade = E.[Classification level]
WHERE B.award <> 'N/A'
AND Pay_Code = 'Base Amount'
and Amount <> '0'
group by
A.Employee_ID
,B.Employee_Start_Date
,B.[Company_Code]
,B.award
,B.level_grade
,B.position
,A.Pay_Code
,A.Pay_Code_Description

*/

