********************************************************************************
* DEPARTMENT STORE LABOR MARKET IMPACT ANALYSIS
* Staggered Difference-in-Differences
*
* This script analyzes the impact of department store openings on local labor
* markets using linked census data and department store opening records.
********************************************************************************

clear all
set more off
set matsize 11000
cap log close

********************************************************************************
* CONFIGURATION - ADJUST THIS PATH FOR YOUR SYSTEM
********************************************************************************

* YOUR PATH - confirmed from your error message
global BASE_PATH "/export/projects4/lzhang_burning_glass_project"

* Data file paths
global CENSUS_DATA   "$BASE_PATH/data/IPUMS/Linked_Census_Final.dta"
global DEPT_STORE    "$BASE_PATH/Yoonjae/department_stores/0_department_opening_firstonly.dta"

* Output directory
global OUTPUT_DIR    "$BASE_PATH/Yoonjae/results/exploratory"

* Create output subdirectories (using shell command that works on Mac/Linux)
!mkdir -p "$OUTPUT_DIR"
!mkdir -p "$OUTPUT_DIR/tables"
!mkdir -p "$OUTPUT_DIR/figures"
!mkdir -p "$OUTPUT_DIR/codebooks"
!mkdir -p "$OUTPUT_DIR/data"

* Start log file
log using "$OUTPUT_DIR/analysis_log.txt", replace text

di "========================================================================"
di "DEPARTMENT STORE LABOR MARKET IMPACT ANALYSIS"
di "Started: $S_DATE $S_TIME"
di "========================================================================"
di ""
di "Configuration:"
di "  Base path: $BASE_PATH"
di "  Census data: $CENSUS_DATA"
di "  Dept store data: $DEPT_STORE"
di "  Output directory: $OUTPUT_DIR"
di ""

********************************************************************************
* SECTION 1: LOAD AND DESCRIBE DATASETS
********************************************************************************

di "========================================================================"
di "SECTION 1: LOADING AND DESCRIBING DATASETS"
di "========================================================================"

*------------------------------------------------------------------------------
* 1.1 Load and describe Census Data
*------------------------------------------------------------------------------
di ""
di "1.1 Loading Census Data..."
di "    Path: $CENSUS_DATA"

use "$CENSUS_DATA", clear

di ""
di "    SUCCESS: Loaded `c(N)' observations, `c(k)' variables"

* Save sample size
local census_n = _N
local census_k = c(k)

* Describe all variables
di ""
di "1.1.1 Census Data Variable List:"
describe, fullnames

* Export variable descriptions
preserve
    describe, replace clear
    export delimited using "$OUTPUT_DIR/tables/census_variables.csv", replace
restore

* Check for year variables and their coverage
di ""
di "1.1.2 Time Period Coverage:"
cap ds *year*
if !_rc {
    local year_vars `r(varlist)'
    di "    Year variables found: `year_vars'"

    foreach yv of local year_vars {
        cap confirm numeric variable `yv'
        if !_rc {
            qui sum `yv'
            di "    `yv': `r(min)' - `r(max)'"
            tab `yv', missing
        }
    }
}
else {
    di "    No year variables found with *year* pattern"
}

* Check occupation variables
di ""
di "1.1.3 Occupation Coding System:"
cap ds *occ*
if !_rc {
    local occ_vars `r(varlist)'
    di "    Occupation variables found: `occ_vars'"

    foreach ov of local occ_vars {
        di ""
        di "    Variable: `ov'"
        cap confirm numeric variable `ov'
        if !_rc {
            qui sum `ov'
            di "        Range: `r(min)' - `r(max)'"
            di "        N non-missing: `r(N)'"

            * Check if has value labels
            local lbl : value label `ov'
            if "`lbl'" != "" {
                di "        Has value labels: Yes (`lbl')"
                di "        First 30 labels:"
                label list `lbl'
            }
            else {
                di "        Has value labels: No"
            }
        }
    }
}
else {
    di "    No occupation variables found with *occ* pattern"
}

* Save census data to permanent file (more robust than tempfile)
save "$OUTPUT_DIR/data/census_temp.dta", replace

*------------------------------------------------------------------------------
* 1.2 Load and describe Department Store Data
*------------------------------------------------------------------------------
di ""
di "========================================================================"
di "1.2 Loading Department Store Opening Data..."
di "    Path: $DEPT_STORE"

use "$DEPT_STORE", clear

di ""
di "    SUCCESS: Loaded `c(N)' observations, `c(k)' variables"

local dept_n = _N
local dept_k = c(k)

* Describe all variables
di ""
di "1.2.1 Department Store Data Variable List:"
describe, fullnames

* Export variable descriptions
preserve
    describe, replace clear
    export delimited using "$OUTPUT_DIR/tables/dept_store_variables.csv", replace
restore

* Sample preview
di ""
di "1.2.2 Sample Data Preview (first 20 observations):"
list in 1/20, clean

* Check year/time variables
di ""
di "1.2.3 Department Store Opening Timeline:"

* Search for year variables (handle case where pattern not found)
cap ds *year*
if !_rc {
    local year_vars_dept `r(varlist)'
    di "    Year-related columns: `year_vars_dept'"
}
else {
    di "    No variables matching *year* found"
    local year_vars_dept ""
}

* Also try *open* pattern
cap ds *open*
if !_rc {
    local open_vars `r(varlist)'
    di "    Open-related columns: `open_vars'"
    local year_vars_dept "`year_vars_dept' `open_vars'"
}

* Show all variables so user can identify the right ones
di ""
di "    ALL VARIABLES IN DEPARTMENT STORE DATA:"
describe, short
ds

foreach yv of local year_vars_dept {
    cap confirm numeric variable `yv'
    if !_rc {
        qui sum `yv'
        di ""
        di "    `yv':"
        di "        Range: `r(min)' - `r(max)'"
        tab `yv', missing
    }
}

* Save department store data
save "$OUTPUT_DIR/data/dept_store_temp.dta", replace

********************************************************************************
* SECTION 2: IDENTIFY COUNTY AND YEAR VARIABLES
********************************************************************************

di ""
di "========================================================================"
di "SECTION 2: IDENTIFYING KEY VARIABLES (COUNTY, YEAR)"
di "========================================================================"

*------------------------------------------------------------------------------
* 2.1 Census Data Key Variables
*------------------------------------------------------------------------------
di ""
di "2.1 Census Data Key Variables:"

use "$OUTPUT_DIR/data/census_temp.dta", clear

* Look for geographic identifiers
di ""
di "    Searching for geographic variables..."
di "    ALL VARIABLES:"
ds

local census_geo_vars ""
cap ds *county*
if !_rc {
    local census_geo_vars "`r(varlist)'"
}
cap ds *fips*
if !_rc {
    local census_geo_vars "`census_geo_vars' `r(varlist)'"
}
cap ds *state*
if !_rc {
    local census_geo_vars "`census_geo_vars' `r(varlist)'"
}
cap ds *icp*
if !_rc {
    local census_geo_vars "`census_geo_vars' `r(varlist)'"
}

di "    Geographic variables found: `census_geo_vars'"

foreach gv of local census_geo_vars {
    di ""
    di "    `gv':"
    qui tab `gv'
    di "        Unique values: `r(r)'"
    cap confirm numeric variable `gv'
    if !_rc {
        qui sum `gv'
        di "        Range: `r(min)' - `r(max)'"
    }
}

* Year variables
di ""
di "    Year variables:"
cap ds *year*
if !_rc {
    local census_year_vars `r(varlist)'
    di "    `census_year_vars'"
}
else {
    di "    No year variables found"
    local census_year_vars ""
}

*------------------------------------------------------------------------------
* 2.2 Department Store Data Key Variables
*------------------------------------------------------------------------------
di ""
di "2.2 Department Store Data Key Variables:"

use "$OUTPUT_DIR/data/dept_store_temp.dta", clear

di ""
di "    ALL VARIABLES:"
ds

local dept_geo_vars ""
cap ds *county*
if !_rc {
    local dept_geo_vars "`r(varlist)'"
}
cap ds *fips*
if !_rc {
    local dept_geo_vars "`dept_geo_vars' `r(varlist)'"
}
cap ds *state*
if !_rc {
    local dept_geo_vars "`dept_geo_vars' `r(varlist)'"
}
cap ds *icp*
if !_rc {
    local dept_geo_vars "`dept_geo_vars' `r(varlist)'"
}

di "    Geographic variables found: `dept_geo_vars'"

foreach gv of local dept_geo_vars {
    cap confirm variable `gv'
    if !_rc {
        di ""
        di "    `gv':"
        qui tab `gv'
        di "        Unique values: `r(r)'"
    }
}

cap ds *year*
if !_rc {
    local dept_year_vars `r(varlist)'
}
else {
    local dept_year_vars ""
}
di ""
di "    Year variables: `dept_year_vars'"

********************************************************************************
* SECTION 3: CREATE TREATMENT VARIABLE
********************************************************************************

di ""
di "========================================================================"
di "SECTION 3: CREATING TREATMENT VARIABLE"
di "========================================================================"

use "$OUTPUT_DIR/data/dept_store_temp.dta", clear

* Show all variables so user knows what's available
di ""
di "3.1 Department store data variables:"
describe
list in 1/10

* Try to identify the year column
local year_col ""
foreach v in year open_year opening_year year_opened first_year {
    cap confirm variable `v'
    if !_rc {
        local year_col "`v'"
        di "    Found year column: `year_col'"
        continue, break
    }
}

* If not found, look for any numeric variable that looks like a year
if "`year_col'" == "" {
    di "    Year column not auto-detected. Searching for year-like variables..."
    ds, has(type numeric)
    foreach v of varlist `r(varlist)' {
        qui sum `v'
        if `r(min)' > 1800 & `r(max)' < 2000 & `r(min)' != `r(max)' {
            local year_col "`v'"
            di "    Using: `year_col' (range: `r(min)' - `r(max)')"
            continue, break
        }
    }
}

* Try to identify geographic column
local geo_col ""
foreach v in fips countyicp county_fips statefip_countyicp icpsr fips_county county stateicp statefip {
    cap confirm variable `v'
    if !_rc {
        local geo_col "`v'"
        di "    Found geographic column: `geo_col'"
        continue, break
    }
}

* If not found, use first non-year variable
if "`geo_col'" == "" {
    di "    Geographic column not auto-detected."
    ds, has(type numeric)
    foreach v of varlist `r(varlist)' {
        if "`v'" != "`year_col'" {
            local geo_col "`v'"
            di "    Using first available: `geo_col'"
            continue, break
        }
    }
}

* Create treatment timing if variables found
if "`year_col'" != "" & "`geo_col'" != "" {
    di ""
    di "3.2 Creating Treatment Timing Variable:"
    di "    Year column: `year_col'"
    di "    Geographic column: `geo_col'"

    * Get first opening year per geographic unit
    bysort `geo_col': egen first_dept_store_year = min(`year_col')

    * Keep one observation per geographic unit
    bysort `geo_col': keep if _n == 1
    keep `geo_col' first_dept_store_year

    di ""
    di "    Number of treated units: `c(N)'"
    qui sum first_dept_store_year
    di "    Treatment year range: `r(min)' - `r(max)'"

    * Distribution of treatment timing
    di ""
    di "    Treatment timing distribution:"
    tab first_dept_store_year, missing

    * Save treatment timing
    export delimited using "$OUTPUT_DIR/tables/treatment_timing.csv", replace
    save "$OUTPUT_DIR/data/treatment_timing.dta", replace

    * Store the geo_col name for later use
    global TREATMENT_GEO_COL "`geo_col'"

    * Create visualization
    hist first_dept_store_year, frequency ///
        title("Distribution of First Department Store Openings") ///
        xtitle("Year") ytitle("Number of Counties") ///
        color(navy%70)
    graph export "$OUTPUT_DIR/figures/treatment_timing_hist.png", replace

    * Cumulative adoption
    preserve
        collapse (count) n_counties = first_dept_store_year, by(first_dept_store_year)
        gen cumulative = sum(n_counties)

        twoway line cumulative first_dept_store_year, ///
            title("Cumulative Department Store Adoption") ///
            xtitle("Year") ytitle("Cumulative Number of Counties") ///
            lcolor(navy) lwidth(medium)
        graph export "$OUTPUT_DIR/figures/cumulative_adoption.png", replace
    restore
}
else {
    di ""
    di "    ERROR: Could not identify key variables."
    di "    Please check variable names above and manually specify:"
    di "    local year_col = YOUR_YEAR_VARIABLE"
    di "    local geo_col = YOUR_GEOGRAPHIC_VARIABLE"
}

********************************************************************************
* SECTION 4: OCCUPATION CODE IDENTIFICATION
********************************************************************************

di ""
di "========================================================================"
di "SECTION 4: OCCUPATION CODE IDENTIFICATION"
di "========================================================================"

use "$OUTPUT_DIR/data/census_temp.dta", clear

*------------------------------------------------------------------------------
* 4.1 Find and examine occupation variables
*------------------------------------------------------------------------------
di ""
di "4.1 Occupation Variables in Census Data:"

cap ds *occ*
if !_rc {
    local occ_vars `r(varlist)'
    di "    Found: `occ_vars'"
}
else {
    di "    No variables matching *occ* found"
    local occ_vars ""
}

* Find the main occupation variable
local main_occ ""
foreach v in occ1950 occ occstr occupation occ1900 occ1920 {
    cap confirm variable `v'
    if !_rc {
        local main_occ "`v'"
        di ""
        di "    Main occupation variable identified: `main_occ'"
        continue, break
    }
}

if "`main_occ'" == "" & "`occ_vars'" != "" {
    local main_occ : word 1 of `occ_vars'
    di "    Using first occupation variable: `main_occ'"
}

*------------------------------------------------------------------------------
* 4.2 Full occupation code listing
*------------------------------------------------------------------------------
di ""
di "4.2 Full Occupation Code Listing:"

if "`main_occ'" != "" {
    * Check for value labels
    local occ_label : value label `main_occ'

    if "`occ_label'" != "" {
        di "    Value label: `occ_label'"
        label list `occ_label'

        * Export full occupation listing with frequencies
        preserve
            contract `main_occ', freq(count)
            decode `main_occ', gen(occ_label)
            gen pct = count / `census_n' * 100
            gsort -count

            export delimited using "$OUTPUT_DIR/tables/occupation_codes_full.csv", replace

            di ""
            di "    Top 30 occupations by frequency:"
            list in 1/30, clean
        restore
    }
    else {
        di "    No value labels found for `main_occ'"
        di "    Showing frequency distribution:"
        tab `main_occ', sort
    }
}

*------------------------------------------------------------------------------
* 4.3 Identify DISPLACED occupations
*------------------------------------------------------------------------------
di ""
di "========================================================================"
di "4.3 DISPLACED OCCUPATIONS"
di "    (Retail merchants, shopkeepers, peddlers, small store owners)"
di "========================================================================"

if "`main_occ'" != "" {
    gen occ_displaced = 0
    label var occ_displaced "1=Occupation likely displaced by dept stores"

    local occ_label : value label `main_occ'

    if "`occ_label'" != "" {
        di ""
        di "    Searching for displaced occupation codes..."
        di "    Keywords: merchant, shopkeeper, peddler, huckster, dealer, vendor, grocer"
        di ""

        * Decode to search labels
        decode `main_occ', gen(occ_label_str)

        * Flag displaced occupations based on label text
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "merchant")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "shopkeeper")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "peddler")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "huckster")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "hawker")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "vendor")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "dealer") & !regexm(lower(occ_label_str), "auto")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "grocer")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "dry goods")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "general store")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "retail.*proprietor")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "store.*owner")

        * Show identified displaced occupations
        di ""
        di "    Identified Displaced Occupations:"
        preserve
            keep if occ_displaced == 1
            if _N > 0 {
                contract `main_occ' occ_label_str, freq(count)
                gsort -count
                list, clean
                export delimited using "$OUTPUT_DIR/tables/displaced_occupations.csv", replace
            }
            else {
                di "    No displaced occupations found with current keywords"
            }
        restore

        di ""
        tab occ_displaced, missing
    }
    else {
        di "    No value labels - cannot search by keyword"
        di "    You may need to manually specify occupation codes"
    }
}

*------------------------------------------------------------------------------
* 4.4 Identify CREATED occupations
*------------------------------------------------------------------------------
di ""
di "========================================================================"
di "4.4 CREATED OCCUPATIONS"
di "    (Department store clerks, salespeople, retail workers)"
di "========================================================================"

if "`main_occ'" != "" {
    gen occ_created = 0
    label var occ_created "1=Occupation likely created by dept stores"

    local occ_label : value label `main_occ'

    if "`occ_label'" != "" {
        di ""
        di "    Searching for created occupation codes..."
        di "    Keywords: clerk, sales, salesman, saleswoman, cashier, retail"
        di ""

        * Flag created occupations based on label text
        cap confirm variable occ_label_str
        if _rc {
            decode `main_occ', gen(occ_label_str)
        }

        replace occ_created = 1 if regexm(lower(occ_label_str), "clerk") & regexm(lower(occ_label_str), "sales")
        replace occ_created = 1 if regexm(lower(occ_label_str), "salesman")
        replace occ_created = 1 if regexm(lower(occ_label_str), "saleswoman")
        replace occ_created = 1 if regexm(lower(occ_label_str), "salesperson")
        replace occ_created = 1 if regexm(lower(occ_label_str), "salesmen")
        replace occ_created = 1 if regexm(lower(occ_label_str), "saleswomen")
        replace occ_created = 1 if regexm(lower(occ_label_str), "cashier")
        replace occ_created = 1 if regexm(lower(occ_label_str), "floorwalker")
        replace occ_created = 1 if regexm(lower(occ_label_str), "floor manager")
        replace occ_created = 1 if regexm(lower(occ_label_str), "department.*head")
        replace occ_created = 1 if regexm(lower(occ_label_str), "buyer.*store")
        replace occ_created = 1 if regexm(lower(occ_label_str), "window.*dresser")
        replace occ_created = 1 if regexm(lower(occ_label_str), "stock.*clerk")
        replace occ_created = 1 if regexm(lower(occ_label_str), "retail.*sales")

        * Show identified created occupations
        di ""
        di "    Identified Created Occupations:"
        preserve
            keep if occ_created == 1
            if _N > 0 {
                contract `main_occ' occ_label_str, freq(count)
                gsort -count
                list, clean
                export delimited using "$OUTPUT_DIR/tables/created_occupations.csv", replace
            }
            else {
                di "    No created occupations found with current keywords"
            }
        restore

        di ""
        tab occ_created, missing
    }
}

*------------------------------------------------------------------------------
* 4.5 Summary of occupation indicators
*------------------------------------------------------------------------------
di ""
di "4.5 Occupation Indicator Summary:"
di ""

cap confirm variable occ_displaced
cap confirm variable occ_created
if !_rc {
    tab occ_displaced occ_created, missing

    qui sum occ_displaced
    di ""
    di "    Displaced occupations: `r(sum)'"
    qui sum occ_created
    di "    Created occupations:   `r(sum)'"
}

*------------------------------------------------------------------------------
* 4.6 Occupation distributions over time
*------------------------------------------------------------------------------
di ""
di "4.6 Occupation Distributions Over Time:"

cap ds *year*
if !_rc {
    local year_vars `r(varlist)'
    local year_col : word 1 of `year_vars'

    di ""
    di "    Using year variable: `year_col'"

    * Displaced by year
    cap confirm variable occ_displaced
    if !_rc {
        di ""
        di "    Displaced Occupations by Year:"
        table `year_col', stat(sum occ_displaced) stat(mean occ_displaced) stat(count occ_displaced)

        preserve
            collapse (sum) n_displaced=occ_displaced (mean) pct_displaced=occ_displaced (count) total=occ_displaced, by(`year_col')
            replace pct_displaced = pct_displaced * 100
            list, clean
            export delimited using "$OUTPUT_DIR/tables/displaced_by_year.csv", replace
        restore
    }

    * Created by year
    cap confirm variable occ_created
    if !_rc {
        di ""
        di "    Created Occupations by Year:"
        table `year_col', stat(sum occ_created) stat(mean occ_created) stat(count occ_created)

        preserve
            collapse (sum) n_created=occ_created (mean) pct_created=occ_created (count) total=occ_created, by(`year_col')
            replace pct_created = pct_created * 100
            list, clean
            export delimited using "$OUTPUT_DIR/tables/created_by_year.csv", replace
        restore
    }

    * Visualization
    cap confirm variable occ_displaced
    cap confirm variable occ_created
    if !_rc {
        preserve
            collapse (mean) pct_displaced=occ_displaced pct_created=occ_created, by(`year_col')
            replace pct_displaced = pct_displaced * 100
            replace pct_created = pct_created * 100

            twoway (bar pct_displaced `year_col', color(red%50)) ///
                   (bar pct_created `year_col', color(green%50)), ///
                title("Occupation Shares Over Time") ///
                xtitle("Census Year") ytitle("Percent") ///
                legend(order(1 "Displaced" 2 "Created"))
            graph export "$OUTPUT_DIR/figures/occupation_trends.png", replace
        restore
    }
}

* Drop temporary label variable
cap drop occ_label_str

* Save census data with occupation indicators
save "$OUTPUT_DIR/data/census_temp.dta", replace

********************************************************************************
* SECTION 5: MERGE DATASETS AND SHOW TREATMENT VARIATION
********************************************************************************

di ""
di "========================================================================"
di "SECTION 5: MERGING DATASETS"
di "========================================================================"

use "$OUTPUT_DIR/data/census_temp.dta", clear

* Identify merge key in census data
di ""
di "5.1 Identifying Merge Keys:"

* List all variables
di "    Census variables:"
ds

* Find potential geographic merge keys
local census_geo_vars ""
foreach pattern in county fips icp {
    cap ds *`pattern'*
    if !_rc {
        local census_geo_vars "`census_geo_vars' `r(varlist)'"
    }
}
di "    Potential geographic variables: `census_geo_vars'"

* Check what's in treatment timing data
use "$OUTPUT_DIR/data/treatment_timing.dta", clear
di ""
di "    Treatment timing variables:"
ds
describe

* Get the geographic variable name from treatment timing
ds
local treatment_vars `r(varlist)'
local treatment_geo_var : word 1 of `treatment_vars'
di "    Treatment geographic variable: `treatment_geo_var'"

* Reload census data
use "$OUTPUT_DIR/data/census_temp.dta", clear

* Try to find matching merge key
local merge_key ""
foreach v in `census_geo_vars' {
    if "`v'" == "`treatment_geo_var'" {
        local merge_key "`v'"
        continue, break
    }
}

* If exact match not found, try common names
if "`merge_key'" == "" {
    foreach v in countyicp county_icp fips county_fips statefip_countyicp {
        cap confirm variable `v'
        if !_rc {
            local merge_key "`v'"
            di "    Using merge key: `merge_key'"
            continue, break
        }
    }
}

* Attempt merge
if "`merge_key'" != "" {
    di ""
    di "5.2 Merging on: `merge_key'"

    * Check if merge key names match
    if "`merge_key'" != "`treatment_geo_var'" {
        di "    Note: Census uses `merge_key', treatment uses `treatment_geo_var'"
        di "    Renaming treatment variable to match..."

        use "$OUTPUT_DIR/data/treatment_timing.dta", clear
        rename `treatment_geo_var' `merge_key'
        save "$OUTPUT_DIR/data/treatment_timing.dta", replace

        use "$OUTPUT_DIR/data/census_temp.dta", clear
    }

    merge m:1 `merge_key' using "$OUTPUT_DIR/data/treatment_timing.dta", keep(master match) gen(_merge_treatment)

    di ""
    di "    Merge Results:"
    tab _merge_treatment

    * Create treatment indicators
    cap ds *year*
    if !_rc {
        local year_col : word 1 of `r(varlist)'

        di ""
        di "5.3 Creating Treatment Indicators:"
        di "    Using year variable: `year_col'"

        * Ever treated
        gen ever_treated = (first_dept_store_year != .)
        label var ever_treated "1=County ever receives department store"

        * Currently treated (post-treatment)
        gen treated = (first_dept_store_year != .) & (`year_col' >= first_dept_store_year)
        label var treated "1=Post-treatment period"

        * Event time
        gen event_time = `year_col' - first_dept_store_year
        label var event_time "Years relative to treatment"

        di ""
        di "    Treatment Variable Summary:"
        di "    ============================="
        tab ever_treated, missing
        di ""
        tab treated, missing
        di ""
        di "    Event time distribution (treated units only):"
        tab event_time if ever_treated == 1, missing
    }

    * Save merged data
    save "$OUTPUT_DIR/data/merged_analysis_data.dta", replace
    export delimited using "$OUTPUT_DIR/data/merged_analysis_data.csv", replace

    di ""
    di "    Merged data saved to: $OUTPUT_DIR/data/merged_analysis_data.dta"
}
else {
    di ""
    di "    WARNING: Could not identify merge key."
    di "    Census geographic variables: `census_geo_vars'"
    di "    Treatment geographic variable: `treatment_geo_var'"
    di "    Please manually specify the merge variable in the code."
}

*------------------------------------------------------------------------------
* 5.4 Treatment Timing Variation
*------------------------------------------------------------------------------
di ""
di "5.4 Treatment Timing Variation:"

cap confirm variable ever_treated
if !_rc {
    tab first_dept_store_year if ever_treated == 1, missing

    * Visualization
    preserve
        keep if ever_treated == 1
        collapse (count) n=ever_treated, by(first_dept_store_year)

        graph bar n, over(first_dept_store_year, label(angle(45))) ///
            title("Treatment Cohort Sizes") ///
            ytitle("Number of Census Observations") ///
            bar(1, color(navy%70))
        graph export "$OUTPUT_DIR/figures/treatment_cohort_sizes.png", replace
    restore
}

save "$OUTPUT_DIR/data/merged_analysis_data.dta", replace

********************************************************************************
* SECTION 6: CREATE CODEBOOK
********************************************************************************

di ""
di "========================================================================"
di "SECTION 6: CREATING CODEBOOK"
di "========================================================================"

file open codebook using "$OUTPUT_DIR/codebooks/codebook.txt", write replace

file write codebook "========================================================================" _n
file write codebook "CODEBOOK: Department Store Labor Market Impact Analysis" _n
file write codebook "Generated: $S_DATE $S_TIME" _n
file write codebook "========================================================================" _n _n

file write codebook "1. DATA SOURCES" _n
file write codebook "----------------------------------------" _n
file write codebook "Census Data: $CENSUS_DATA" _n
file write codebook "Department Store Data: $DEPT_STORE" _n _n

file write codebook "2. TREATMENT VARIABLES" _n
file write codebook "----------------------------------------" _n
file write codebook "first_dept_store_year: Year county first received department store" _n
file write codebook "ever_treated: 1=County ever receives department store" _n
file write codebook "treated: 1=Post-treatment period" _n
file write codebook "event_time: Years relative to treatment" _n _n

file write codebook "3. OCCUPATION CLASSIFICATION" _n
file write codebook "----------------------------------------" _n
file write codebook "occ_displaced: 1=Occupation likely displaced by dept stores" _n
file write codebook "  Keywords: merchant, shopkeeper, peddler, huckster, dealer, vendor, grocer" _n _n
file write codebook "occ_created: 1=Occupation likely created by dept stores" _n
file write codebook "  Keywords: clerk, sales, salesman, saleswoman, cashier, retail" _n

file close codebook

di "    Codebook saved to: $OUTPUT_DIR/codebooks/codebook.txt"

********************************************************************************
* SECTION 7: SUMMARY STATISTICS
********************************************************************************

di ""
di "========================================================================"
di "SECTION 7: GENERATING SUMMARY STATISTICS"
di "========================================================================"

use "$OUTPUT_DIR/data/merged_analysis_data.dta", clear

*------------------------------------------------------------------------------
* 7.1 Sample sizes
*------------------------------------------------------------------------------
di ""
di "7.1 Sample Size Summary:"

cap confirm variable ever_treated
if !_rc {
    di ""
    di "    By treatment status:"
    tab ever_treated, missing
}

cap ds *year*
if !_rc {
    local year_col : word 1 of `r(varlist)'

    cap confirm variable ever_treated
    if !_rc {
        di ""
        di "    By treatment status and year:"
        tab `year_col' ever_treated, missing
    }
}

*------------------------------------------------------------------------------
* 7.2 Outcome variables summary
*------------------------------------------------------------------------------
di ""
di "7.2 Outcome Variables Summary:"

foreach v in occ_displaced occ_created {
    cap confirm variable `v'
    if !_rc {
        di ""
        di "    `v':"
        sum `v', detail
    }
}

*------------------------------------------------------------------------------
* 7.3 Occupation distribution by treatment status
*------------------------------------------------------------------------------
di ""
di "7.3 Occupation Distribution by Treatment Status:"

cap confirm variable occ_displaced
cap confirm variable ever_treated
if !_rc {
    di ""
    di "    Displaced Occupations:"
    table ever_treated, stat(sum occ_displaced) stat(mean occ_displaced) stat(count occ_displaced)
}

cap confirm variable occ_created
cap confirm variable ever_treated
if !_rc {
    di ""
    di "    Created Occupations:"
    table ever_treated, stat(sum occ_created) stat(mean occ_created) stat(count occ_created)
}

********************************************************************************
* SECTION 8: VISUALIZATIONS
********************************************************************************

di ""
di "========================================================================"
di "SECTION 8: CREATING VISUALIZATIONS"
di "========================================================================"

*------------------------------------------------------------------------------
* 8.1 Pre-trends in key outcomes
*------------------------------------------------------------------------------
di ""
di "8.1 Pre-Trends in Key Outcomes:"

cap ds *year*
if !_rc {
    local year_col : word 1 of `r(varlist)'
}

cap confirm variable occ_displaced
cap confirm variable ever_treated
if !_rc {
    preserve
        collapse (mean) occ_displaced, by(`year_col' ever_treated)
        replace occ_displaced = occ_displaced * 100

        reshape wide occ_displaced, i(`year_col') j(ever_treated)

        twoway (line occ_displaced0 `year_col', lcolor(blue) lwidth(medium)) ///
               (line occ_displaced1 `year_col', lcolor(red) lwidth(medium)), ///
            title("Pre-Trends: Displaced Occupations") ///
            xtitle("Census Year") ytitle("Percent") ///
            legend(order(1 "Never Treated" 2 "Ever Treated"))
        graph export "$OUTPUT_DIR/figures/pretrend_displaced.png", replace
    restore
}

cap confirm variable occ_created
cap confirm variable ever_treated
if !_rc {
    preserve
        collapse (mean) occ_created, by(`year_col' ever_treated)
        replace occ_created = occ_created * 100

        reshape wide occ_created, i(`year_col') j(ever_treated)

        twoway (line occ_created0 `year_col', lcolor(blue) lwidth(medium)) ///
               (line occ_created1 `year_col', lcolor(red) lwidth(medium)), ///
            title("Pre-Trends: Created Occupations") ///
            xtitle("Census Year") ytitle("Percent") ///
            legend(order(1 "Never Treated" 2 "Ever Treated"))
        graph export "$OUTPUT_DIR/figures/pretrend_created.png", replace
    restore
}

*------------------------------------------------------------------------------
* 8.2 Event Study Plot
*------------------------------------------------------------------------------
di ""
di "8.2 Event Study Plots:"

cap confirm variable event_time
cap confirm variable occ_displaced
if !_rc {
    preserve
        keep if ever_treated == 1
        keep if event_time >= -20 & event_time <= 20

        collapse (mean) mean=occ_displaced (sd) sd=occ_displaced (count) n=occ_displaced, by(event_time)
        gen se = sd / sqrt(n)
        gen ci_lo = mean - 1.96*se
        gen ci_hi = mean + 1.96*se

        twoway (rcap ci_lo ci_hi event_time, lcolor(gray)) ///
               (scatter mean event_time, mcolor(navy) msize(small)), ///
            xline(0, lcolor(red) lpattern(dash)) ///
            title("Event Study: Displaced Occupations") ///
            xtitle("Years Relative to Treatment") ytitle("Share") ///
            legend(off)
        graph export "$OUTPUT_DIR/figures/event_study_displaced.png", replace
    restore
}

cap confirm variable event_time
cap confirm variable occ_created
if !_rc {
    preserve
        keep if ever_treated == 1
        keep if event_time >= -20 & event_time <= 20

        collapse (mean) mean=occ_created (sd) sd=occ_created (count) n=occ_created, by(event_time)
        gen se = sd / sqrt(n)
        gen ci_lo = mean - 1.96*se
        gen ci_hi = mean + 1.96*se

        twoway (rcap ci_lo ci_hi event_time, lcolor(gray)) ///
               (scatter mean event_time, mcolor(green) msize(small)), ///
            xline(0, lcolor(red) lpattern(dash)) ///
            title("Event Study: Created Occupations") ///
            xtitle("Years Relative to Treatment") ytitle("Share") ///
            legend(off)
        graph export "$OUTPUT_DIR/figures/event_study_created.png", replace
    restore
}

********************************************************************************
* FINAL SUMMARY
********************************************************************************

di ""
di "========================================================================"
di "ANALYSIS COMPLETE"
di "========================================================================"
di ""
di "End time: $S_DATE $S_TIME"
di ""
di "Outputs saved to: $OUTPUT_DIR"
di "  - tables/: CSV tables"
di "  - figures/: PNG visualizations"
di "  - codebooks/: Variable documentation"
di "  - data/: Merged analysis dataset"
di ""

log close

********************************************************************************
* END OF SCRIPT
********************************************************************************
