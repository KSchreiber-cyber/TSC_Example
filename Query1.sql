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


---------------------------------------------------------------------------------------------------------------
--Count of hourly rate difference  into RAW_Employee_Count_Hourly_Difference
---------------------------------------------------------------------------------------------------------------

drop table if exists RAW_Employee_Count_Hourly_Difference

select 
Employee_ID AS Employee_ID
, a.Hourly_Difference AS Hourly_Difference
,count(Hourly_Difference)  AS Count_Hourly_Difference
into RAW_Employee_Count_Hourly_Difference
from RAW_Employee_Hourly_Rate_Difference as a
where a.amount <> '0'
group by Employee_ID, a.Hourly_Difference



 ---------------------------------------------------------------------------------------------------------------------
-- Base pay difference annualised - on  [Applicable Rate Prescribed Under the Award] column AN
---------------------------------------------------------------------------------------------------------------------
SELECT
T.*, CONVERT(DECIMAL(8,2), T.HOURLY_RATE_DIFFERENCE * 52 * T.[Hours Week]) AS 'DIFFERENCE ANNUALLY'
into RAW_BASE_PAY_DIFFERENCE_ANNUALISED
FROM
(
SELECT
[Staff Member],
T.Amount_Value, E.[Hours Week],
CASE WHEN CONVERT(FLOAT, E.[Applicable Rate Prescribed Under the Award]) > 100 THEN CONVERT(DECIMAL(5, 2), (CONVERT(FLOAT, E.[Applicable Rate Prescribed Under the Award])/(52 * CONVERT(FLOAT, E.[Hours Week]))))
       ELSE CONVERT(FLOAT, E.[Applicable Rate Prescribed Under the Award])
END AS RAW_employee,
CASE WHEN CONVERT(FLOAT, E.[Applicable Rate Prescribed Under the Award]) > 100 THEN CONVERT(DECIMAL(5, 2), (CONVERT(FLOAT, E.[Applicable Rate Prescribed Under the Award])/(52 * CONVERT(FLOAT, E.[Hours Week])))) - T.Amount_Value
       ELSE  CONVERT(DECIMAL(5, 2), (CONVERT(FLOAT, E.[Applicable Rate Prescribed Under the Award]))) - T.Amount_Value
END AS 'HOURLY_RATE_DIFFERENCE'
FROM RAW_EMPLOYEES AS E
INNER JOIN
(SELECT D.*, C.[Applicable Award / EBA], C.Classification, C.[Classification level], C.[Job Title], C.[Job Title1], C.[Length of service] FROM  REF_Award_Position_Mapping AS C
INNER JOIN REF_EBA_Wages_Allowances AS D
on C.Instrument = D.Instrument
and C.Classification = D.Position) AS T
ON E.[Applicable Award   EBA] = T.[Applicable Award / EBA] AND LTRIM(RTRIM(T.[Classification level])) = RTRIM(LTRIM(E.[Classification level]))
WHERE E.[Applicable Rate Prescribed Under the Award] NOT IN ('', ' N/A ', 'N/A', 'Y')) AS T
ORDER BY [DIFFERENCE ANNUALLY]


 ---------------------------------------------------------------------------------------------------------------------
-- Base pay difference annualised - on [BASE_ANNUALLY] column Z
---------------------------------------------------------------------------------------------------------------------

SELECT
T.[Staff Member], T.[Hours Week], T.[BASE_ANNUALLY] AS 'RAW_DATA_BASE_ANNUALLY', T.Amount_Value * [Hours Week] * 52 AS 'CALCULATED_ANNUALLY', T.[BASE_ANNUALLY] - T.Amount_Value * [Hours Week] * 52 AS 'DIFFERENCE'
into RAW_BASE_PAY_DIFFERENCE_ANNUALISED2
FROM
(
SELECT
[Staff Member],
T.Amount_Value,
E.[Hours Week],
E.[BASE_ANNUALLY],
CASE WHEN CONVERT(FLOAT, E.[Applicable Rate Prescribed Under the Award]) > 100 THEN CONVERT(DECIMAL(5, 2), (CONVERT(FLOAT, E.[Applicable Rate Prescribed Under the Award])/(52 * CONVERT(FLOAT, E.[Hours Week]))))
       ELSE CONVERT(FLOAT, E.[Applicable Rate Prescribed Under the Award])
END AS RAW_employee,
CASE WHEN CONVERT(FLOAT, E.[Applicable Rate Prescribed Under the Award]) > 100 THEN CONVERT(DECIMAL(5, 2), (CONVERT(FLOAT, E.[Applicable Rate Prescribed Under the Award])/(52 * CONVERT(FLOAT, E.[Hours Week])))) - T.Amount_Value
       ELSE  CONVERT(DECIMAL(5, 2), (CONVERT(FLOAT, E.[Applicable Rate Prescribed Under the Award]))) - T.Amount_Value
END AS 'DIFFERENCE'
FROM RAW_EMPLOYEES AS E
INNER JOIN
(SELECT D.*, C.[Applicable Award / EBA], C.Classification, C.[Classification level], C.[Job Title], C.[Job Title1], C.[Length of service] FROM  REF_Award_Position_Mapping AS C
INNER JOIN REF_EBA_Wages_Allowances AS D
on C.Instrument = D.Instrument
and C.Classification = D.Position) AS T
ON E.[Applicable Award   EBA] = T.[Applicable Award / EBA] AND LTRIM(RTRIM(T.[Classification level])) = RTRIM(LTRIM(E.[Classification level]))
WHERE E.[Applicable Rate Prescribed Under the Award] NOT IN ('', ' N/A ', 'N/A', 'Y')) AS T
ORDER BY DIFFERENCE desc









 ---------------------------------------------------------------------------------------------------------------------
-- BAD Kim code 
/*
---------------------------------------------------------------------------------------------------------------------

drop table if exists #Hourly_Rate_Difference2
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
INTO #Hourly_Rate_Difference2
from FACT_Payslip_Details A
left join FACT_Employees B
on a.Employee_ID = b.Employee_ID
left join #Award_Join E
on B.award=E.[Applicable Award / EBA]
and b.level_grade = E.[Classification level]
WHERE [Hours] <> '0'
AND B.award <> 'N/A'
order by award asc





SELECT
T.[k_psd_id] 
	,T.[k_ps_id] 
	,T.[k_emp_id] 
	,T.[Employee_ID] 
	,T.[Employee_Start_Date] 
	,T.[award] 
	,T.[level_grade] 
	,T.[position] 
	,T.[pay_cycle] 
	,T.[Pay_Period_From] 
	,T.[Pay_Period_To] 
	,T.[pay_date] 
	,T.[k_days_since_last_ps] 
	,T.[k_pay_cycle] 
	,T.[Pay_Code] 
	,T.[Pay_Code_Description] 
	,T.[Amount] 
	,T.[Hours]
	,T.[Calcualted_hourly_rate]
	,T.[EBA_Hourly_Rate] 
	,T.[Hourly_Difference]

--INTO FACT_Hourly_Rate_Difference
FROM
 (SELECT [k_psd_id] 
	,[k_ps_id] 
	,[k_emp_id] 
	,[Employee_ID] 
	,[Employee_Start_Date]
	,[award] 
	,[level_grade] 
	,[position] 
	,[pay_cycle] 
	,[Pay_Period_From] 
	,[Pay_Period_To] 
	,[pay_date] 
	,[k_days_since_last_ps] 
	,[k_pay_cycle] 
	,[Pay_Code] 
	,[Pay_Code_Description] 
	,[Amount] 
	,[Hours]
	,[Calcualted_hourly_rate]
	,[EBA_Hourly_Rate] 
	,[Hourly_Difference]
								  FROM [dbo].#Hourly_Rate_Difference1
			UNION ALL
						  SELECT [k_psd_id] 
	,[k_ps_id] 
	,[k_emp_id] 
	,[Employee_ID] 
	,[Employee_Start_Date]
	,[award] 
	,[level_grade] 
	,[position] 
	,[pay_cycle] 
	,[Pay_Period_From] 
	,[Pay_Period_To] 
	,[pay_date] 
	,[k_days_since_last_ps] 
	,[k_pay_cycle] 
	,[Pay_Code] 
	,[Pay_Code_Description] 
	,[Amount] 
	,[Hours]
	,[Calcualted_hourly_rate]
	,[EBA_Hourly_Rate] 
	,[Hourly_Difference]
								 FROM [dbo].#Hourly_Rate_Difference2) T; 

								 
 ---------------------------------------------------------------------------------------------------------------------
*/
--Old Casey code
/*
---------------------------------------------------------------------------------------------------------------------



--SLEEPOVER SHIFT COUNT AND AMOUNT
SELECT SUM([S/O_COUNT_PS]) AS PS_SO_CT
	  ,SUM([S/O_COUNT_TS]) AS TS_SO
	  ,sum([s/o_pay_PS]) as PS_SO_Pay
	  ,sum([s/o_pay_tS]) as tS_SO_Pay
FROM FACT_payslip_timesheet_final


--S/O shift comparison of night to afternoon rate for Ord hours
select
	sum(case when shift_row_id = 1 then 1 else 0 end) as 'Total S/O Shifts',
	avg(case when shift_row_id = 1 then act_hours end) as 'Avg S/O hours',
	sum(Calc_Hrs_TS) as 'Total S/O Hours',
	sum(Ord_Hrs_TS) as 'Total Ord S/O Hours',
	sum(case when Ord_Hrs_TS = 0 then Calc_Hrs_TS end) as 'Total Other S/O Hours',
	sum(total_so_nightrate) as 'Total Ord Hours at Night Penalty',
	sum(total_so_afternoonrate) as 'Total Ord Hours at Afternoon Penalty'

from
	(select 
		Calc_Hrs_TS * (Ord_Rate_TS * 1.25) * 0.15 as total_so_nightrate,
		Calc_Hrs_TS * (Ord_Rate_TS * 1.25) * 0.125 as total_so_afternoonrate,

		* 
	from FACT_timesheet_summarytable where location = 'sleepover shift'
	) a

select sum([S/O_COUNT_PS]), sum([s/o_count_ts]) from FACT_payslip_timesheet_summary

---------------------------------------------------------------------------------------------------------------------

--OT MEALS COUNT AND AMOUNT
SELECT SUM(OT_MEAL_COUNT) 
	,SUM(CASE WHEN OT_MEAL_COUNT = 1 THEN 1 ELSE 0 END) AS MEAL1
	,SUM(CASE WHEN OT_MEAL_COUNT = 2 THEN 1 ELSE 0 END) AS MEAL2 
FROM FACT_timesheet_summarytable

SELECT 
	SUM(OT_MEAL_CT_TS) AS MEAL
	,SUM(OT_MEAL_AMT_TS) AS MEAL_AMT
FROM FACT_payslip_timesheet_summary


---------------------------------------------------------------------------------------------------------------------
-- MIN HOURS CHECK

select * from remove2 where position = 'Welfare' and location <> 'Sleepover Shift' AND ACT_HOURS+Transport_Hours <2
union all
select * from remove2 where position = 'Day Services' and location <> 'Sleepover Shift' AND ACT_HOURS+Transport_Hours <3
--72


--WELFARE
select * from FACT_timesheet_summarytable where position = 'welfare' and Calc_Hrs_TS <2 and location <> 'Sleepover Shift' AND ACT_HOURS <2
--62
select sum(total_amt + pen_amt) as actual_amt,
	   sum(min_hours_amt + isnull(min_hours_pen,0)) as min_amount
from
(select 
	act_hours
	,Calc_Hrs_TS
	,ord_amt_ts + Sat_AMT_TS + Sun_AMT_TS + PH_AMT_TS as total_amt
	,Night_AMT_TS+Afternoon_AMT_TS as pen_amt
	,case when ord_hrs_ts <> 0 then 2*ord_rate_ts*(1+ord_factor_ts)
		  when sat_rate_ts <> 0 then 2*sat_rate_ts*(1+sat_factor_ts)
		  when sun_rate_ts <> 0 then 2*sun_rate_ts*(1+sun_factor_ts)
		  when ph_rate_ts <> 0 then 2*ph_rate_ts*(1+ph_factor_ts)
	end as min_hours_amt
	,case when Afternoon_Hrs_TS <> 0 then 2*Afternoon_Rate_TS*Afternoon_Factor_TS
		  when night_hrs_ts <> 0 then 2*Night_Rate_TS*Night_Factor_TS
	end as min_hours_pen
	--,* 
	from FACT_timesheet_summarytable where position = 'welfare' and Calc_Hrs_TS <2 and location <> 'Sleepover Shift' AND ACT_HOURS <2
) A
--62

--check if any likely s/o
select * from FACT_timesheet_summarytable where position = 'welfare' and Act_Hours <2 and location = 'Sleepover Shift'
--0




--DAY SERVICES
select * from FACT_timesheet_summarytable where position = 'day services' and Calc_Hrs_TS <3 and location <> 'Sleepover Shift'
--8

select sum(total_amt + pen_amt) as actual_amt,
	   sum(min_hours_amt + isnull(min_hours_pen,0)) as min_amount
from
(select 
	act_hours
	,Calc_Hrs_TS
	,ord_amt_ts + Sat_AMT_TS + Sun_AMT_TS + PH_AMT_TS as total_amt
	,Night_AMT_TS+Afternoon_AMT_TS as pen_amt
	,case when ord_hrs_ts <> 0 then 3*ord_rate_ts*(1+ord_factor_ts)
		  when sat_rate_ts <> 0 then 3*sat_rate_ts*(1+sat_factor_ts)
		  when sun_rate_ts <> 0 then 3*sun_rate_ts*(1+sun_factor_ts)
		  when ph_rate_ts <> 0 then 3*ph_rate_ts*(1+ph_factor_ts)
	end as min_hours_amt
	,case when Afternoon_Hrs_TS <> 0 then 3*Afternoon_Rate_TS*Afternoon_Factor_TS
		  when night_hrs_ts <> 0 then 3*Night_Rate_TS*Night_Factor_TS
	end as min_hours_pen
	--,* 
	from FACT_timesheet_summarytable where position = 'day services' and Calc_Hrs_TS <3 and location <> 'Sleepover Shift' AND ACT_HOURS <3
) A
--7


--check if any likely s/0
select * from FACT_timesheet_summarytable where position = 'day services' and Act_Hours <3 and location = 'Sleepover Shift'
--0


---------------------------------------------------------------------------------------------------------------------

--SHIFT STARTS WITH 10MINS OF PREVIOUS SHIFT

select A.K_EMP_ID, A.ROW_ID, A.k_Timesheet_ID, a.hours_type, a.[Start_Date], A.DATETIME_in, A.DATETIME_OUT, 
		B.Row_ID, B.k_Timesheet_ID, b.hours_type, B.[Start_Date], B.DATETIME_IN, b.DATETIME_OUT,  DATEDIFF(MINUTE, A.DATETIME_OUT,  B.DATETIME_IN)
from 
	FACT_timesheet_summarytable A
inner join
	FACT_timesheet_summarytable b
ON A.K_emp_ID = B.K_emp_ID
AND A.ROW_ID = B.ROW_ID-1
WHERE DATEDIFF(MINUTE, A.DATETIME_OUT,  B.DATETIME_IN) <=10



---------------------------------------------------------------------------------------------------------------------

--PAYSLIPS AND TIMESHEETS FOR VALIDATION

SELECT * FROM FACT_timesheet_summarytable WHERE k_ps_id IN (
'ps1003-20170730',
'ps1003-20170813',
'ps1008-20180128',
'ps10297-20170716',
'ps10297-20170723',
'ps10297-20170730',
'ps10297-20170806',
'ps10297-20180610',
'ps10297-20180617',
'ps10343-20180401',
'ps10343-20180617',
'ps10430-20170709',
'ps10430-20170716',
'ps10430-20170723',
'ps10430-20170806',
'ps10430-20170813',
'ps10430-20170903',
'ps10430-20170910',
'ps10430-20171001',
'ps10430-20171008',
'ps10430-20171029',
'ps10430-20171119',
'ps10430-20171126',
'ps10430-20171217',
'ps10561-20170813',
'ps10561-20170903',
'ps10669-20170813',
'ps10685-20171015',
'ps10685-20171224',
'ps10739-20170820',
'ps10856-20171008',
'ps10894-20180121',
'ps10959-20171210',
'ps10959-20180114',
'ps10977-20180121',
'ps11188-20170730',
'ps11231-20170709',
'ps11508-20170924',
'ps11576-20170723',
'ps11648-20180401',
'ps11648-20180617',
'ps11717-20180128',
'ps11761-20171015',
'ps11771-20180401',
'ps11796-20171112',
'ps11839-20170723',
'ps11923-20170827',
'ps13771-20171224',
'ps14043-20171210',
'ps15452-20170924',
'ps15681-20180311',
'ps17288-20171224',
'ps17502-20171231',
'ps17627-20180204',
'ps17976-20180408',
'ps19849-20180617',
'ps20018-20180408',
'ps20053-20171224',
'ps20607-20180513',
'ps21143-20171224',
'ps21188-20170917',
'ps21254-20180408',
'ps21330-20171217',
'ps21330-20180429',
'ps21431-20171224',
'ps21439-20171008',
'ps21569-20171224',
'ps21643-20180304',
'ps21750-20171224',
'ps22516-20171203',
'ps23014-20171105',
'ps23264-20171008',
'ps23462-20180128',
'ps23534-20180107',
'ps24062-20180311',
'ps2514-20170730',
'ps5761-20171022',
'ps6912-20180506',
'ps7515-20171224',
'ps7550-20180204',
'ps7673-20171022',
'ps8226-20171022',
'ps8425-20170730',
'ps8679-20171210',
'ps9036-20180422',
'ps9994-20180401')


SELECT * FROM FACT_timesheet_summarytable WHERE Employee_ID = '15108' and Pay_date = '2018-03-29'
union all
SELECT * FROM FACT_timesheet_summarytable WHERE Employee_ID = '16539' and Pay_date = '2018-01-04'
union all
SELECT * FROM FACT_timesheet_summarytable WHERE Employee_ID = '17424' and Pay_date = '2017-10-26'
union all
SELECT * FROM FACT_timesheet_summarytable WHERE Employee_ID = '20848' and Pay_date = '2017-08-31'
union all
SELECT * FROM FACT_timesheet_summarytable WHERE Employee_ID = '23014' and Pay_date = '2017-10-05'
union all
SELECT * FROM FACT_timesheet_summarytable WHERE Employee_ID = '23136' and Pay_date = '2018-03-01'
union all
SELECT * FROM FACT_timesheet_summarytable WHERE Employee_ID = '23576' and Pay_date = '2017-11-30'



SELECT * FROM FACT_Payslip_Details WHERE k_ps_id IN (
'ps1003-20170730',
'ps1003-20170813',
'ps1008-20180128',
'ps10297-20170716',
'ps10297-20170723',
'ps10297-20170730',
'ps10297-20170806',
'ps10297-20180610',
'ps10297-20180617',
'ps10343-20180401',
'ps10343-20180617',
'ps10430-20170709',
'ps10430-20170716',
'ps10430-20170723',
'ps10430-20170806',
'ps10430-20170813',
'ps10430-20170903',
'ps10430-20170910',
'ps10430-20171001',
'ps10430-20171008',
'ps10430-20171029',
'ps10430-20171119',
'ps10430-20171126',
'ps10430-20171217',
'ps10561-20170813',
'ps10561-20170903',
'ps10669-20170813',
'ps10685-20171015',
'ps10685-20171224',
'ps10739-20170820',
'ps10856-20171008',
'ps10894-20180121',
'ps10959-20171210',
'ps10959-20180114',
'ps10977-20180121',
'ps11188-20170730',
'ps11231-20170709',
'ps11508-20170924',
'ps11576-20170723',
'ps11648-20180401',
'ps11648-20180617',
'ps11717-20180128',
'ps11761-20171015',
'ps11771-20180401',
'ps11796-20171112',
'ps11839-20170723',
'ps11923-20170827',
'ps13771-20171224',
'ps14043-20171210',
'ps15452-20170924',
'ps15681-20180311',
'ps17288-20171224',
'ps17502-20171231',
'ps17627-20180204',
'ps17976-20180408',
'ps19849-20180617',
'ps20018-20180408',
'ps20053-20171224',
'ps20607-20180513',
'ps21143-20171224',
'ps21188-20170917',
'ps21254-20180408',
'ps21330-20171217',
'ps21330-20180429',
'ps21431-20171224',
'ps21439-20171008',
'ps21569-20171224',
'ps21643-20180304',
'ps21750-20171224',
'ps22516-20171203',
'ps23014-20171105',
'ps23264-20171008',
'ps23462-20180128',
'ps23534-20180107',
'ps24062-20180311',
'ps2514-20170730',
'ps5761-20171022',
'ps6912-20180506',
'ps7515-20171224',
'ps7550-20180204',
'ps7673-20171022',
'ps8226-20171022',
'ps8425-20170730',
'ps8679-20171210',
'ps9036-20180422',
'ps9994-20180401')

*/
