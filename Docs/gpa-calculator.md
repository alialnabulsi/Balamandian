# GPA Calculator

The student-only `/tools/gpa` screen uses the shared shell and Back to Tools.
Student-containing mixed roles qualify; guest sign-in and profile loading/retry
remain separate. Compact course rows, Add course, a semester GPA banner, manual
prior credits/average, Import GPA & CGPA from SIS, and the projected cumulative
value replace the earlier explanatory panels and mode/source controls.

## Calculation

Courses require name/code (100 Unicode characters), positive counted credits
and numeric grade /100 (40-100). Plain decimals are accepted; invalid, nonfinite
and overflowing values are rejected. Zero completed credits is a first semester;
missing prior values never silently become zero. An incomplete course suppresses
predictions; an incomplete prior baseline affects cumulative projection only.

Numeric semester average = sum(grade * credits) / counted credits. Cumulative
projection = (prior numeric weighted total + course weighted total) / total
counted credits. Imported totals remain exact; no reconstruction from rounded
GPA equivalents. Current term GPA is displayed separately from CGPA and is never
counted twice. Manual edits and temporary scenarios make no network requests.

Existing policy `uob-spring-2018-2019-floor-v1` remains unchanged: map the final
weighted numeric average through the detailed university equivalence table,
using the lower integer for fractional averages. This app estimate is not an
official registrar prediction for repeats, transfers or special notations.
The compact screen omits the earlier method/source sheet as requested; policy
remains documented here:
[official equivalence table](https://www.balamand.edu.lb/Style%20Library/PDFs/CurrentStudents/AverageGPA.pdf),
[undergraduate catalogue](https://www.balamand.edu.lb/Style%20Library/PDFs/Catalogue/General-Section-Undergraduate.pdf).

## SIS import and caching

Flutter uses ProfileApiService and its existing authenticated session boundary.
GET `/api/v1/profile/me/academics` reads the private app cache; explicit Import
uses POST `/api/v1/profile/me/academics/sync`. The app backend uses the approved
read-only connection to original SIS enrollments/courses/sections/semesters.
SIS-API is unchanged; no new SIS endpoint or table is required.

Imported values are explicitly calculated from completed/failed numeric SIS
grades using the existing calculator policy. They are not presented as stored
registrar-approved summaries. Conflicting, missing or unsupported grades and
repeated attempts produce a useful import message and preserve manual input.
Current-term GPA is separate from cumulative GPA; the exact numeric weighted
cumulative total is used without double counting. No publication time is invented.

Private profile display reads cached data only. Import fields are disabled while
pending. Account changes, reset, logout and navigation invalidate late imports.
The supported contract and source limitations are documented in the backend
[academic integration](../../Balamandian-API/docs/academics.md).
