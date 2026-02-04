# Department Store Labor Market Impact Analysis

Staggered Difference-in-Differences analysis of department store openings on local labor markets.

## Quick Start (Stata)

### 1. Configure File Path

Open `department_store_analysis.do` and edit the `BASE_PATH` global (around line 20):

```stata
* Find your mount point by running in Terminal: df -h | grep projects
global BASE_PATH "/Volumes/projects4/lzhang_burning_glass_project"
```

### 2. Run the Analysis

In Stata:
```stata
do "/path/to/department_store_analysis.do"
```

Or double-click the .do file to open in Stata and run.

## What the Script Does

| Section | Description |
|---------|-------------|
| **1. Data Loading** | Loads census data and department store openings, describes all variables |
| **2. Key Variables** | Identifies county/geographic identifiers and year variables |
| **3. Treatment Variable** | Creates `first_dept_store_year` for each county |
| **4. Occupation Codes** | Classifies occupations as DISPLACED or CREATED |
| **5. Data Merge** | Merges datasets, creates `ever_treated`, `treated`, `event_time` |
| **6. Codebook** | Generates documentation of all variables |
| **7. Summary Stats** | Pre-treatment balance, outcome summaries |
| **8. Visualizations** | Pre-trends, event studies, composition changes |

## Occupation Classification

### DISPLACED Occupations (`occ_displaced=1`)
Occupations likely negatively affected by department stores:
- Keywords: merchant, shopkeeper, peddler, huckster, dealer, vendor, grocer, dry goods

### CREATED Occupations (`occ_created=1`)
Occupations likely created/expanded by department stores:
- Keywords: clerk, sales, salesman, saleswoman, cashier, floorwalker, retail

## Output Structure

All outputs saved to: `Yoonjae/results/exploratory/`

```
results/exploratory/
├── tables/
│   ├── census_variables.csv
│   ├── dept_store_variables.csv
│   ├── occupation_codes_full.csv
│   ├── displaced_occupations.csv
│   ├── created_occupations.csv
│   ├── treatment_timing.csv
│   └── sample_by_year.csv
├── figures/
│   ├── treatment_timing_hist.png
│   ├── cumulative_adoption.png
│   ├── occupation_trends.png
│   ├── pretrend_displaced.png
│   ├── pretrend_created.png
│   ├── event_study_displaced.png
│   ├── event_study_created.png
│   └── occupation_composition_combined.png
├── codebooks/
│   └── codebook.txt
├── data/
│   ├── treatment_timing.dta
│   ├── merged_analysis_data.dta
│   └── merged_analysis_data.csv
└── analysis_log.txt
```

## Key Variables Created

| Variable | Description |
|----------|-------------|
| `first_dept_store_year` | Year county first received department store |
| `ever_treated` | 1 if county ever receives department store |
| `treated` | 1 if post-treatment (census year >= opening year) |
| `event_time` | Years relative to treatment (-/0/+) |
| `occ_displaced` | 1 if in displaced occupation |
| `occ_created` | 1 if in created occupation |

## Troubleshooting

### "File not found" error
1. Check that the network drive is mounted (look in Finder sidebar)
2. Open Terminal and run: `ls /Volumes/`
3. Update `BASE_PATH` in the script to match

### Finding the correct mount path
```bash
# In Terminal:
df -h | grep -i project
ls /Volumes/
find /Volumes -name "Linked_Census_Final.dta" 2>/dev/null
```

### Variable name mismatches
The script tries to auto-detect variable names. If merge fails:
1. Check the log file for available variable names
2. Manually set the merge key in Section 5

## Customizing Occupation Classifications

Edit Section 4 to add/remove occupation keywords:

```stata
* Add more displaced keywords:
replace occ_displaced = 1 if regexm(lower(occ_label_str), "your_keyword")

* Add specific occupation codes:
replace occ_displaced = 1 if inlist(`main_occ', 144, 290, YOUR_CODE)
```

## Next Steps After Running

1. **Check the log file** (`analysis_log.txt`) for any warnings
2. **Review occupation classifications** in the CSV files
3. **Examine pre-trends** - parallel trends assumption
4. **Use merged data** for formal DiD estimation:

```stata
* Load merged data
use "$OUTPUT_DIR/data/merged_analysis_data.dta", clear

* Basic DiD (for illustration - use proper estimators for staggered timing)
reghdfe occ_created treated, absorb(county_id year) cluster(county_id)

* For staggered DiD, use:
* - csdid (Callaway & Sant'Anna)
* - eventstudyinteract (Sun & Abraham)
* - did_imputation (Borusyak et al.)
```

## Recommended Stata Packages for Staggered DiD

```stata
* Install packages
ssc install reghdfe
ssc install ftools
ssc install csdid
ssc install drdid
net install eventstudyinteract, from("https://raw.githubusercontent.com/lsun20/eventstudyinteract/main/")
```
