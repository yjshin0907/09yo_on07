# Department Store Labor Market Impact Analysis

Staggered Difference-in-Differences analysis of department store openings on local labor markets.

## Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure File Paths

Open `department_store_analysis.py` and edit the `BASE_PATH` variable (around line 35):

```python
# Find your mount point by:
# 1. Open Terminal
# 2. Run: df -h | grep projects
# 3. Use the mount point shown

# Common Mac SMB mount paths:
BASE_PATH = "/Volumes/projects4/lzhang_burning_glass_project"

# OR if mounted differently:
# BASE_PATH = "/Volumes/lzhang_burning_glass_project"
```

### 3. Run the Analysis

```bash
python department_store_analysis.py
```

## What the Script Does

### Section 1: Data Loading
- Loads census data (`Linked_Census_Final.dta`)
- Loads department store openings (`0_department_opening_firstonly.dta`)
- Describes variables, sample sizes, time periods

### Section 2: Key Variable Identification
- Identifies county/geographic identifiers
- Identifies year variables
- Recommends merge keys

### Section 3: Treatment Variable Creation
- Creates `first_dept_store_year`: Year of first department store in county
- Visualizes treatment timing distribution

### Section 4: Occupation Code Identification
- **DISPLACED occupations**: Retail merchants, shopkeepers, peddlers, hucksters
- **CREATED occupations**: Department store clerks, salespeople, retail workers
- Creates indicator variables: `occ_displaced`, `occ_created`
- Shows frequency distributions over time

### Section 5: Dataset Merging
- Merges census and department store data
- Creates treatment indicators:
  - `ever_treated`: County ever receives department store
  - `treated`: Currently in post-treatment period
  - `event_time`: Years relative to treatment

### Section 6: Codebook
- Comprehensive documentation of all variables
- Occupation classification methodology

### Section 7: Summary Statistics
- Pre-treatment balance tables
- Outcome variable summaries
- Occupation distributions by treatment status

### Section 8: Visualizations
- Department store adoption over time
- Pre-trends in outcomes
- Event study plots
- Occupation composition changes

## Output Structure

All outputs saved to: `Yoonjae/results/exploratory/`

```
results/exploratory/
├── tables/           # CSV and formatted text tables
├── figures/          # PNG visualizations
├── codebooks/        # Variable documentation
└── data/             # Merged analysis dataset
```

## Key Output Files

| File | Description |
|------|-------------|
| `tables/census_variables.csv` | Census variable list with labels |
| `tables/occupation_codes_full.csv` | All occupation codes and frequencies |
| `tables/displaced_occupations.csv` | Occupations classified as displaced |
| `tables/created_occupations.csv` | Occupations classified as created |
| `tables/pretreatment_balance.csv` | Balance table by treatment status |
| `figures/treatment_timing_distribution.png` | When counties get treated |
| `figures/pretrends.png` | Pre-treatment outcome trends |
| `figures/event_study_raw.png` | Raw event study plots |
| `codebooks/codebook.txt` | Full variable documentation |
| `data/merged_analysis_data.csv` | Merged dataset for further analysis |

## Troubleshooting

### "File not found" error
1. Check that the network drive is mounted
2. Verify the mount path: `df -h` in Terminal
3. Update `BASE_PATH` in the script

### "No module named 'pyreadstat'" error
```bash
pip install pyreadstat
```

### Mac-specific issues
If you have trouble with SMB mounts, try:
```bash
# List all mounted volumes
ls /Volumes/

# Find the exact path
find /Volumes -name "Linked_Census_Final.dta" 2>/dev/null
```

## Customization

### Adding More Occupation Classifications

Edit the `identify_occupation_codes()` function:

```python
# Add keywords for displaced occupations
displaced_keywords = [
    'merchant', 'shopkeeper', 'store owner', ...
    'YOUR_NEW_KEYWORD',  # Add here
]

# Add specific occupation codes
displaced_occ_codes_1950 = {
    144: "Hucksters and peddlers",
    YOUR_CODE: "Your description",  # Add here
}
```

### Changing Output Directory

Edit line ~43:
```python
OUTPUT_DIR = "/your/custom/output/path"
```

## Next Steps After Running

1. **Review occupation classifications** in `displaced_occupations.csv` and `created_occupations.csv`
2. **Check pre-trends** in `figures/pretrends.png` - parallel trends assumption
3. **Examine event study** in `figures/event_study_raw.png` - treatment dynamics
4. **Use merged data** in `data/merged_analysis_data.csv` for formal DiD estimation

## Recommended Estimation

For staggered DiD with heterogeneous treatment timing, consider:
- **Callaway & Sant'Anna (2021)**: `did` package in R or `csdid` in Stata
- **Sun & Abraham (2021)**: Interaction-weighted estimator
- **Borusyak, Jaravel & Spiess (2024)**: Imputation estimator
