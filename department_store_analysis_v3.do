********************************************************************************
* DEPARTMENT STORE LABOR MARKET IMPACT ANALYSIS
* Staggered Difference-in-Differences
* VERSION 3 - FULLY CORRECTED WITH INTERMEDIATE SAVES
*
* This script analyzes the impact of department store openings on local labor
* markets using linked census data and department store opening records.
*
* KEY FEATURES:
* - Saves intermediate files so you can restart from any section
* - All ds commands use cap to handle missing patterns
* - Robust error handling throughout
********************************************************************************

clear all
set more off
set matsize 11000
cap log close

********************************************************************************
* CONFIGURATION - ADJUST THIS PATH FOR YOUR SYSTEM
********************************************************************************

global BASE_PATH "/export/projects4/lzhang_burning_glass_project"

* Data file paths
global CENSUS_DATA   "$BASE_PATH/data/IPUMS/Linked_Census_Final.dta"
global DEPT_STORE    "$BASE_PATH/Yoonjae/department_stores/0_department_opening_firstonly.dta"

* Output directory
global OUTPUT_DIR    "$BASE_PATH/Yoonjae/results/exploratory"

* Create output subdirectories
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

* Save sample size to globals so they persist
global census_n = _N
global census_k = c(k)

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
    di "    No year variables found"
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
    di "    No occupation variables found"
}

* SAVE TO PERMANENT FILE (so you can restart from here)
save "$OUTPUT_DIR/data/census_temp.dta", replace
di ""
di "    >>> Census data saved to: $OUTPUT_DIR/data/census_temp.dta"

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

global dept_n = _N
global dept_k = c(k)

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

* Check year/time variables - search each pattern separately
di ""
di "1.2.3 Department Store Opening Timeline:"

local year_vars_dept ""
cap ds *year*
if !_rc {
    local year_vars_dept "`r(varlist)'"
}
cap ds *open*
if !_rc {
    local year_vars_dept "`year_vars_dept' `r(varlist)'"
}

if "`year_vars_dept'" != "" {
    di "    Year-related columns: `year_vars_dept'"

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
}
else {
    di "    No year-related variables found. Showing all variables:"
    ds
}

* SAVE TO PERMANENT FILE
save "$OUTPUT_DIR/data/dept_store_temp.dta", replace
di ""
di "    >>> Dept store data saved to: $OUTPUT_DIR/data/dept_store_temp.dta"

di ""
di "========================================================================"
di "SECTION 1 COMPLETE"
di "========================================================================"

********************************************************************************
* SECTION 2: IDENTIFY COUNTY AND YEAR VARIABLES
*
* TO RESTART FROM HERE, RUN:
*   use "$OUTPUT_DIR/data/census_temp.dta", clear
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

* Look for geographic identifiers - search each pattern separately with cap
di ""
di "    Searching for geographic variables..."

local census_geo_vars ""
cap ds *county*
if !_rc {
    local census_geo_vars "`census_geo_vars' `r(varlist)'"
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

* Remove leading/trailing spaces and duplicates
local census_geo_vars = trim("`census_geo_vars'")
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
local census_year_vars ""
cap ds *year*
if !_rc {
    local census_year_vars "`r(varlist)'"
}
cap ds *yr*
if !_rc {
    local census_year_vars "`census_year_vars' `r(varlist)'"
}
di "    `census_year_vars'"

* Save to globals for later use
global CENSUS_GEO_VARS "`census_geo_vars'"
global CENSUS_YEAR_VARS "`census_year_vars'"

*------------------------------------------------------------------------------
* 2.2 Department Store Data Key Variables
*------------------------------------------------------------------------------
di ""
di "2.2 Department Store Data Key Variables:"

use "$OUTPUT_DIR/data/dept_store_temp.dta", clear

di ""
di "    Searching for geographic variables..."

local dept_geo_vars ""
cap ds *county*
if !_rc {
    local dept_geo_vars "`dept_geo_vars' `r(varlist)'"
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

local dept_geo_vars = trim("`dept_geo_vars'")
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

local dept_year_vars ""
cap ds *year*
if !_rc {
    local dept_year_vars "`r(varlist)'"
}
cap ds *open*
if !_rc {
    local dept_year_vars "`dept_year_vars' `r(varlist)'"
}
di ""
di "    Year variables: `dept_year_vars'"

* Save to globals
global DEPT_GEO_VARS "`dept_geo_vars'"
global DEPT_YEAR_VARS "`dept_year_vars'"

di ""
di "========================================================================"
di "SECTION 2 COMPLETE"
di "========================================================================"

********************************************************************************
* SECTION 3: CREATE TREATMENT VARIABLE
*
* TO RESTART FROM HERE, RUN:
*   use "$OUTPUT_DIR/data/dept_store_temp.dta", clear
********************************************************************************

di ""
di "========================================================================"
di "SECTION 3: CREATING TREATMENT VARIABLE"
di "========================================================================"

use "$OUTPUT_DIR/data/dept_store_temp.dta", clear

* Show all variables
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

* If not found, use first numeric variable that looks like a year
if "`year_col'" == "" {
    di "    Year column not auto-detected. Searching..."
    ds, has(type numeric)
    foreach v of varlist `r(varlist)' {
        qui sum `v'
        if `r(min)' > 1800 & `r(max)' < 2000 {
            local year_col "`v'"
            di "    Using: `year_col' (range: `r(min)' - `r(max)')"
            continue, break
        }
    }
}

* Try to identify geographic column
local geo_col ""
foreach v in countyicp fips county_fips statefip_countyicp icpsr fips_county county stateicp statefip {
    cap confirm variable `v'
    if !_rc {
        local geo_col "`v'"
        di "    Found geographic column: `geo_col'"
        continue, break
    }
}

* If not found, use first non-year numeric variable
if "`geo_col'" == "" {
    di "    Geographic column not auto-detected. Using first available..."
    ds, has(type numeric)
    foreach v of varlist `r(varlist)' {
        if "`v'" != "`year_col'" {
            local geo_col "`v'"
            di "    Using: `geo_col'"
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

    * Save the column names to globals
    global TREATMENT_YEAR_COL "`year_col'"
    global TREATMENT_GEO_COL "`geo_col'"

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

    * SAVE TO PERMANENT FILE
    export delimited using "$OUTPUT_DIR/tables/treatment_timing.csv", replace
    save "$OUTPUT_DIR/data/treatment_timing.dta", replace
    di ""
    di "    >>> Treatment timing saved to: $OUTPUT_DIR/data/treatment_timing.dta"

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
    di "    Please check the variable names above and manually specify:"
    di "    local year_col YOUR_YEAR_VARIABLE"
    di "    local geo_col YOUR_GEOGRAPHIC_VARIABLE"
    exit 1
}

di ""
di "========================================================================"
di "SECTION 3 COMPLETE"
di "========================================================================"

********************************************************************************
* SECTION 4: OCCUPATION CODE IDENTIFICATION
*
* TO RESTART FROM HERE, RUN:
*   use "$OUTPUT_DIR/data/census_temp.dta", clear
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

local occ_vars ""
cap ds *occ*
if !_rc {
    local occ_vars `r(varlist)'
    di "    Found: `occ_vars'"
}
else {
    di "    No variables matching *occ* found"
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

* Save to global
global MAIN_OCC "`main_occ'"

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
            gen pct = count / $census_n * 100
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
    cap drop occ_displaced
    gen occ_displaced = 0
    label var occ_displaced "1=Occupation likely displaced by dept stores"

    local occ_label : value label `main_occ'

    if "`occ_label'" != "" {
        di ""
        di "    Searching for displaced occupation codes..."
        di "    Keywords: merchant, shopkeeper, peddler, huckster, dealer, vendor, grocer"
        di ""

        * Decode to search labels
        cap drop occ_label_str
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
    cap drop occ_created
    gen occ_created = 0
    label var occ_created "1=Occupation likely created by dept stores"

    local occ_label : value label `main_occ'

    if "`occ_label'" != "" {
        di ""
        di "    Searching for created occupation codes..."
        di "    Keywords: clerk, sales, salesman, saleswoman, cashier, retail"
        di ""

        * Make sure occ_label_str exists
        cap confirm variable occ_label_str
        if _rc {
            decode `main_occ', gen(occ_label_str)
        }

        * Flag created occupations based on label text
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
    local n_displaced = r(sum)
    qui sum occ_created
    local n_created = r(sum)

    di ""
    di "    Displaced occupations: `n_displaced'"
    di "    Created occupations:   `n_created'"
}

*------------------------------------------------------------------------------
* 4.6 Occupation distributions over time
*------------------------------------------------------------------------------
di ""
di "4.6 Occupation Distributions Over Time:"

* Find year variable
local year_col ""
cap ds *year*
if !_rc {
    local year_vars `r(varlist)'
    local year_col : word 1 of `year_vars'
}

if "`year_col'" != "" {
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

* SAVE census data with occupation indicators
save "$OUTPUT_DIR/data/census_with_occ.dta", replace
di ""
di "    >>> Census data with occupations saved to: $OUTPUT_DIR/data/census_with_occ.dta"

di ""
di "========================================================================"
di "SECTION 4 COMPLETE"
di "========================================================================"

********************************************************************************
* SECTION 5: MERGE DATASETS AND SHOW TREATMENT VARIATION
*
* TO RESTART FROM HERE, RUN:
*   use "$OUTPUT_DIR/data/census_with_occ.dta", clear
********************************************************************************

di ""
di "========================================================================"
di "SECTION 5: MERGING DATASETS"
di "========================================================================"

use "$OUTPUT_DIR/data/census_with_occ.dta", clear

* Identify merge key in census data
di ""
di "5.1 Identifying Merge Keys:"

* Find potential geographic merge keys
local census_geo_vars ""
cap ds *county*
if !_rc {
    local census_geo_vars "`census_geo_vars' `r(varlist)'"
}
cap ds *fips*
if !_rc {
    local census_geo_vars "`census_geo_vars' `r(varlist)'"
}
cap ds *icp*
if !_rc {
    local census_geo_vars "`census_geo_vars' `r(varlist)'"
}
local census_geo_vars = trim("`census_geo_vars'")
di "    Census geographic variables: `census_geo_vars'"

* Check what's in treatment timing data
use "$OUTPUT_DIR/data/treatment_timing.dta", clear
di ""
di "    Treatment timing variables:"
ds
describe

* Get the geographic variable name from treatment timing
ds
local treatment_vars `r(varlist)'
local treatment_geo_var ""
foreach v of local treatment_vars {
    if "`v'" != "first_dept_store_year" {
        local treatment_geo_var "`v'"
    }
}
di "    Treatment geographic variable: `treatment_geo_var'"

* Reload census data
use "$OUTPUT_DIR/data/census_with_occ.dta", clear

* Try to find matching merge key
local merge_key ""

* First check if exact match exists
cap confirm variable `treatment_geo_var'
if !_rc {
    local merge_key "`treatment_geo_var'"
    di "    Found exact match: `merge_key'"
}

* If not found, try common names
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

    * If merge key names differ, rename in treatment file
    if "`merge_key'" != "`treatment_geo_var'" {
        di "    Note: Census uses `merge_key', treatment uses `treatment_geo_var'"
        di "    Renaming treatment variable to match..."

        use "$OUTPUT_DIR/data/treatment_timing.dta", clear
        rename `treatment_geo_var' `merge_key'
        save "$OUTPUT_DIR/data/treatment_timing_renamed.dta", replace

        use "$OUTPUT_DIR/data/census_with_occ.dta", clear
        merge m:1 `merge_key' using "$OUTPUT_DIR/data/treatment_timing_renamed.dta", keep(master match) gen(_merge_treatment)
    }
    else {
        merge m:1 `merge_key' using "$OUTPUT_DIR/data/treatment_timing.dta", keep(master match) gen(_merge_treatment)
    }

    di ""
    di "    Merge Results:"
    tab _merge_treatment

    * Find year variable
    local year_col ""
    cap ds *year*
    if !_rc {
        foreach v of varlist `r(varlist)' {
            if "`v'" != "first_dept_store_year" {
                local year_col "`v'"
                continue, break
            }
        }
    }

    if "`year_col'" != "" {
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

    * SAVE merged data
    save "$OUTPUT_DIR/data/merged_analysis_data.dta", replace
    export delimited using "$OUTPUT_DIR/data/merged_analysis_data.csv", replace
    di ""
    di "    >>> Merged data saved to: $OUTPUT_DIR/data/merged_analysis_data.dta"
}
else {
    di ""
    di "    ERROR: Could not identify merge key."
    di "    Census geographic variables: `census_geo_vars'"
    di "    Treatment geographic variable: `treatment_geo_var'"
    di "    Please manually specify the merge variable."
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

di ""
di "========================================================================"
di "SECTION 5 COMPLETE"
di "========================================================================"

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
file write codebook "  - Observations: $census_n" _n
file write codebook "  - Variables: $census_k" _n _n
file write codebook "Department Store Data: $DEPT_STORE" _n
file write codebook "  - Observations: $dept_n" _n
file write codebook "  - Variables: $dept_k" _n _n

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

di ""
di "========================================================================"
di "SECTION 6 COMPLETE"
di "========================================================================"

********************************************************************************
* SECTION 7: SUMMARY STATISTICS
*
* TO RESTART FROM HERE, RUN:
*   use "$OUTPUT_DIR/data/merged_analysis_data.dta", clear
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

* Find year variable
local year_col ""
cap ds *year*
if !_rc {
    foreach v of varlist `r(varlist)' {
        if "`v'" != "first_dept_store_year" {
            local year_col "`v'"
            continue, break
        }
    }
}

cap confirm variable ever_treated
if !_rc & "`year_col'" != "" {
    di ""
    di "    By treatment status and year:"
    tab `year_col' ever_treated, missing
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

di ""
di "========================================================================"
di "SECTION 7 COMPLETE"
di "========================================================================"

********************************************************************************
* SECTION 8: VISUALIZATIONS
*
* TO RESTART FROM HERE, RUN:
*   use "$OUTPUT_DIR/data/merged_analysis_data.dta", clear
********************************************************************************

di ""
di "========================================================================"
di "SECTION 8: CREATING VISUALIZATIONS"
di "========================================================================"

use "$OUTPUT_DIR/data/merged_analysis_data.dta", clear

* Find year variable
local year_col ""
cap ds *year*
if !_rc {
    foreach v of varlist `r(varlist)' {
        if "`v'" != "first_dept_store_year" {
            local year_col "`v'"
            continue, break
        }
    }
}

*------------------------------------------------------------------------------
* 8.1 Pre-trends in key outcomes
*------------------------------------------------------------------------------
di ""
di "8.1 Pre-Trends in Key Outcomes:"

cap confirm variable occ_displaced
cap confirm variable ever_treated
if !_rc & "`year_col'" != "" {
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
    di "    Saved: pretrend_displaced.png"
}

cap confirm variable occ_created
cap confirm variable ever_treated
if !_rc & "`year_col'" != "" {
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
    di "    Saved: pretrend_created.png"
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
    di "    Saved: event_study_displaced.png"
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
    di "    Saved: event_study_created.png"
}

*------------------------------------------------------------------------------
* 8.3 Combined visualization
*------------------------------------------------------------------------------
di ""
di "8.3 Combined Occupation Trends:"

cap confirm variable occ_displaced
cap confirm variable occ_created
cap confirm variable ever_treated
if !_rc & "`year_col'" != "" {
    preserve
        collapse (mean) occ_displaced occ_created, by(`year_col' ever_treated)
        replace occ_displaced = occ_displaced * 100
        replace occ_created = occ_created * 100

        twoway (line occ_displaced `year_col' if ever_treated==1, lcolor(red) lwidth(medium)) ///
               (line occ_created `year_col' if ever_treated==1, lcolor(green) lwidth(medium)) ///
               (line occ_displaced `year_col' if ever_treated==0, lcolor(red) lwidth(medium) lpattern(dash)) ///
               (line occ_created `year_col' if ever_treated==0, lcolor(green) lwidth(medium) lpattern(dash)), ///
            title("Occupation Composition Over Time") ///
            xtitle("Census Year") ytitle("Percent") ///
            legend(order(1 "Displaced (Treated)" 2 "Created (Treated)" ///
                        3 "Displaced (Control)" 4 "Created (Control)") rows(2))
        graph export "$OUTPUT_DIR/figures/occupation_composition_combined.png", replace
    restore
    di "    Saved: occupation_composition_combined.png"
}

di ""
di "========================================================================"
di "SECTION 8 COMPLETE"
di "========================================================================"

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
di "SAVED INTERMEDIATE FILES (for restarting):"
di "  - $OUTPUT_DIR/data/census_temp.dta"
di "  - $OUTPUT_DIR/data/dept_store_temp.dta"
di "  - $OUTPUT_DIR/data/treatment_timing.dta"
di "  - $OUTPUT_DIR/data/census_with_occ.dta"
di "  - $OUTPUT_DIR/data/merged_analysis_data.dta"
di ""
di "OUTPUTS:"
di "  - tables/: CSV tables"
di "  - figures/: PNG visualizations"
di "  - codebooks/: Variable documentation"
di ""

log close

********************************************************************************
* END OF SCRIPT
********************************************************************************
