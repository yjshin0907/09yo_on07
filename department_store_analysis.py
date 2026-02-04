#!/usr/bin/env python3
"""
Department Store Labor Market Impact Analysis
==============================================
Staggered Difference-in-Differences Analysis

This script analyzes the impact of department store openings on local labor markets
using linked census data and department store opening records.

Author: Analysis Script for Labor Economics Research
Date: February 2026
"""

import os
import sys
import warnings
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
import pyreadstat
import matplotlib.pyplot as plt
import seaborn as sns
from tabulate import tabulate

warnings.filterwarnings('ignore')

# =============================================================================
# CONFIGURATION - ADJUST THESE PATHS FOR YOUR SYSTEM
# =============================================================================

# Base path - adjust this to your mounted drive location
# Common Mac SMB mount paths:
#   /Volumes/projects4/lzhang_burning_glass_project/
#   /Volumes/lzhang_burning_glass_project/
# Check your Finder sidebar or use 'df -h' in terminal to find the mount point

BASE_PATH = "/Volumes/projects4/lzhang_burning_glass_project"

# Alternative: If mounted differently, uncomment and modify:
# BASE_PATH = "/Volumes/lzhang_burning_glass_project"

# Data file paths (relative to BASE_PATH)
CENSUS_DATA_PATH = os.path.join(BASE_PATH, "data/IPUMS/Linked_Census_Final.dta")
DEPT_STORE_PATH = os.path.join(BASE_PATH, "Yoonjae/department_stores/0_department_opening_firstonly.dta")

# Output directory
OUTPUT_DIR = os.path.join(BASE_PATH, "Yoonjae/results/exploratory")

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def create_output_dirs():
    """Create output directories if they don't exist."""
    dirs = [
        OUTPUT_DIR,
        os.path.join(OUTPUT_DIR, "tables"),
        os.path.join(OUTPUT_DIR, "figures"),
        os.path.join(OUTPUT_DIR, "codebooks"),
        os.path.join(OUTPUT_DIR, "data")
    ]
    for d in dirs:
        Path(d).mkdir(parents=True, exist_ok=True)
    print(f"Output directories created/verified at: {OUTPUT_DIR}")

def save_table(df, filename, title=""):
    """Save a DataFrame as both CSV and formatted text."""
    # Save CSV
    csv_path = os.path.join(OUTPUT_DIR, "tables", f"{filename}.csv")
    df.to_csv(csv_path)

    # Save formatted text
    txt_path = os.path.join(OUTPUT_DIR, "tables", f"{filename}.txt")
    with open(txt_path, 'w') as f:
        if title:
            f.write(f"{title}\n")
            f.write("=" * len(title) + "\n\n")
        f.write(tabulate(df, headers='keys', tablefmt='grid', showindex=True))
        f.write("\n")

    print(f"  Saved: {csv_path}")
    return csv_path

def save_figure(fig, filename):
    """Save a matplotlib figure."""
    fig_path = os.path.join(OUTPUT_DIR, "figures", f"{filename}.png")
    fig.savefig(fig_path, dpi=150, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    print(f"  Saved: {fig_path}")
    return fig_path

# =============================================================================
# SECTION 1: LOAD AND DESCRIBE DATASETS
# =============================================================================

def load_and_describe_data():
    """Load both datasets and provide comprehensive descriptions."""

    print("\n" + "="*80)
    print("SECTION 1: LOADING AND DESCRIBING DATASETS")
    print("="*80)

    results = {}

    # -------------------------------------------------------------------------
    # Load Census Data
    # -------------------------------------------------------------------------
    print("\n1.1 Loading Census Data...")
    print(f"    Path: {CENSUS_DATA_PATH}")

    try:
        census_df, census_meta = pyreadstat.read_dta(CENSUS_DATA_PATH)
        print(f"    SUCCESS: Loaded {len(census_df):,} observations, {len(census_df.columns)} variables")
        results['census'] = {
            'data': census_df,
            'meta': census_meta,
            'n_obs': len(census_df),
            'n_vars': len(census_df.columns)
        }
    except FileNotFoundError:
        print(f"    ERROR: File not found at {CENSUS_DATA_PATH}")
        print("    Please check your BASE_PATH configuration.")
        sys.exit(1)
    except Exception as e:
        print(f"    ERROR: {str(e)}")
        sys.exit(1)

    # -------------------------------------------------------------------------
    # Load Department Store Data
    # -------------------------------------------------------------------------
    print("\n1.2 Loading Department Store Opening Data...")
    print(f"    Path: {DEPT_STORE_PATH}")

    try:
        dept_df, dept_meta = pyreadstat.read_dta(DEPT_STORE_PATH)
        print(f"    SUCCESS: Loaded {len(dept_df):,} observations, {len(dept_df.columns)} variables")
        results['dept_store'] = {
            'data': dept_df,
            'meta': dept_meta,
            'n_obs': len(dept_df),
            'n_vars': len(dept_df.columns)
        }
    except FileNotFoundError:
        print(f"    ERROR: File not found at {DEPT_STORE_PATH}")
        print("    Please check your BASE_PATH configuration.")
        sys.exit(1)
    except Exception as e:
        print(f"    ERROR: {str(e)}")
        sys.exit(1)

    # -------------------------------------------------------------------------
    # Describe Census Data
    # -------------------------------------------------------------------------
    print("\n" + "-"*80)
    print("1.3 CENSUS DATA DESCRIPTION")
    print("-"*80)

    census_df = results['census']['data']
    census_meta = results['census']['meta']

    # Variable list with labels
    print("\n1.3.1 Variable List with Labels:")
    var_info = []
    for col in census_df.columns:
        label = census_meta.column_names_to_labels.get(col, "")
        dtype = str(census_df[col].dtype)
        n_missing = census_df[col].isna().sum()
        n_unique = census_df[col].nunique()
        var_info.append({
            'Variable': col,
            'Label': label[:50] + '...' if len(str(label)) > 50 else label,
            'Type': dtype,
            'Missing': n_missing,
            'Unique': n_unique
        })

    var_info_df = pd.DataFrame(var_info)
    print(tabulate(var_info_df, headers='keys', tablefmt='simple', showindex=False))
    save_table(var_info_df, "census_variables", "Census Data Variable List")

    # Time period
    print("\n1.3.2 Time Period Coverage:")
    year_cols = [c for c in census_df.columns if 'year' in c.lower()]
    for yc in year_cols:
        if census_df[yc].dtype in ['int64', 'float64', 'int32', 'float32']:
            print(f"    {yc}: {int(census_df[yc].min())} - {int(census_df[yc].max())}")
            print(f"        Unique values: {sorted(census_df[yc].dropna().unique().astype(int))}")

    # Sample size by year
    if year_cols:
        main_year = year_cols[0]
        year_counts = census_df[main_year].value_counts().sort_index()
        print(f"\n    Sample size by {main_year}:")
        for yr, cnt in year_counts.items():
            print(f"        {int(yr)}: {cnt:,}")

    # Occupation coding system
    print("\n1.3.3 Occupation Coding System:")
    occ_cols = [c for c in census_df.columns if 'occ' in c.lower()]
    print(f"    Occupation-related variables found: {occ_cols}")

    for occ_col in occ_cols[:3]:  # Check first 3 occupation columns
        if occ_col in census_meta.variable_value_labels:
            labels = census_meta.variable_value_labels[occ_col]
            print(f"\n    {occ_col} value labels (first 20):")
            for i, (code, label) in enumerate(list(labels.items())[:20]):
                print(f"        {code}: {label}")
            if len(labels) > 20:
                print(f"        ... and {len(labels) - 20} more codes")
        else:
            unique_vals = census_df[occ_col].dropna().unique()
            print(f"\n    {occ_col}: {len(unique_vals)} unique values (no labels in metadata)")
            print(f"        Range: {census_df[occ_col].min()} - {census_df[occ_col].max()}")

    # -------------------------------------------------------------------------
    # Describe Department Store Data
    # -------------------------------------------------------------------------
    print("\n" + "-"*80)
    print("1.4 DEPARTMENT STORE DATA DESCRIPTION")
    print("-"*80)

    dept_df = results['dept_store']['data']
    dept_meta = results['dept_store']['meta']

    # Variable list
    print("\n1.4.1 Variable List with Labels:")
    dept_var_info = []
    for col in dept_df.columns:
        label = dept_meta.column_names_to_labels.get(col, "")
        dtype = str(dept_df[col].dtype)
        n_missing = dept_df[col].isna().sum()
        n_unique = dept_df[col].nunique()
        dept_var_info.append({
            'Variable': col,
            'Label': label[:50] + '...' if len(str(label)) > 50 else label,
            'Type': dtype,
            'Missing': n_missing,
            'Unique': n_unique
        })

    dept_var_info_df = pd.DataFrame(dept_var_info)
    print(tabulate(dept_var_info_df, headers='keys', tablefmt='simple', showindex=False))
    save_table(dept_var_info_df, "dept_store_variables", "Department Store Data Variable List")

    # Sample preview
    print("\n1.4.2 Sample Data Preview:")
    print(dept_df.head(10).to_string())

    # Time coverage
    print("\n1.4.3 Department Store Opening Timeline:")
    year_cols_dept = [c for c in dept_df.columns if 'year' in c.lower() or 'open' in c.lower()]
    print(f"    Year-related columns: {year_cols_dept}")

    for yc in year_cols_dept:
        if dept_df[yc].dtype in ['int64', 'float64', 'int32', 'float32']:
            print(f"\n    {yc}:")
            print(f"        Range: {int(dept_df[yc].min())} - {int(dept_df[yc].max())}")
            print(f"        Distribution:")
            dist = dept_df[yc].value_counts().sort_index()
            for yr, cnt in dist.head(20).items():
                print(f"            {int(yr)}: {cnt} stores")

    return results

# =============================================================================
# SECTION 2: IDENTIFY COUNTY AND YEAR VARIABLES
# =============================================================================

def identify_key_variables(results):
    """Identify county and year variables in each dataset."""

    print("\n" + "="*80)
    print("SECTION 2: IDENTIFYING KEY VARIABLES (COUNTY, YEAR)")
    print("="*80)

    census_df = results['census']['data']
    dept_df = results['dept_store']['data']

    # -------------------------------------------------------------------------
    # Census Data
    # -------------------------------------------------------------------------
    print("\n2.1 Census Data Key Variables:")

    # Look for county/geographic identifiers
    geo_patterns = ['county', 'fips', 'state', 'countyicp', 'statefip', 'stateicp']
    census_geo_cols = [c for c in census_df.columns if any(p in c.lower() for p in geo_patterns)]
    print(f"\n    Geographic variables found: {census_geo_cols}")

    for gc in census_geo_cols:
        n_unique = census_df[gc].nunique()
        print(f"        {gc}: {n_unique} unique values")
        if n_unique < 100:
            print(f"            Sample values: {sorted(census_df[gc].dropna().unique())[:10]}")

    # Year variables
    year_patterns = ['year', 'yr']
    census_year_cols = [c for c in census_df.columns if any(p in c.lower() for p in year_patterns)]
    print(f"\n    Year variables found: {census_year_cols}")

    for yc in census_year_cols:
        unique_years = sorted(census_df[yc].dropna().unique())
        print(f"        {yc}: {unique_years}")

    # -------------------------------------------------------------------------
    # Department Store Data
    # -------------------------------------------------------------------------
    print("\n2.2 Department Store Data Key Variables:")

    dept_geo_cols = [c for c in dept_df.columns if any(p in c.lower() for p in geo_patterns)]
    print(f"\n    Geographic variables found: {dept_geo_cols}")

    for gc in dept_geo_cols:
        n_unique = dept_df[gc].nunique()
        print(f"        {gc}: {n_unique} unique values")

    dept_year_cols = [c for c in dept_df.columns if any(p in c.lower() for p in year_patterns)]
    print(f"\n    Year variables found: {dept_year_cols}")

    # Store identified variables
    results['key_vars'] = {
        'census_geo': census_geo_cols,
        'census_year': census_year_cols,
        'dept_geo': dept_geo_cols,
        'dept_year': dept_year_cols
    }

    # Recommend merge keys
    print("\n2.3 Recommended Merge Keys:")
    print("    Based on variable inspection, likely merge keys are:")
    print("    - County: Look for matching FIPS codes or county ICP codes")
    print("    - State: stateicp or statefip variables")
    print("    - Year: Match census year to department store opening year")

    return results

# =============================================================================
# SECTION 3: CREATE TREATMENT VARIABLE
# =============================================================================

def create_treatment_variable(results):
    """Create treatment variable indicating first department store opening."""

    print("\n" + "="*80)
    print("SECTION 3: CREATING TREATMENT VARIABLE")
    print("="*80)

    dept_df = results['dept_store']['data'].copy()

    # Find the year column (likely contains 'year' or 'open')
    year_col = None
    for col in dept_df.columns:
        if 'year' in col.lower():
            year_col = col
            break

    if year_col is None:
        print("    WARNING: Could not identify year column. Using first numeric column.")
        numeric_cols = dept_df.select_dtypes(include=[np.number]).columns
        if len(numeric_cols) > 0:
            year_col = numeric_cols[0]

    print(f"\n3.1 Using '{year_col}' as the opening year variable")

    # Find geographic identifier
    geo_col = None
    geo_patterns = ['fips', 'county', 'countyicp']
    for pattern in geo_patterns:
        for col in dept_df.columns:
            if pattern in col.lower():
                geo_col = col
                break
        if geo_col:
            break

    print(f"3.2 Using '{geo_col}' as the geographic identifier")

    # Create treatment timing variable
    # For first department store opening per county
    print("\n3.3 Creating Treatment Timing Variable:")

    if geo_col and year_col:
        # Get first opening year per geographic unit
        treatment_timing = dept_df.groupby(geo_col)[year_col].min().reset_index()
        treatment_timing.columns = [geo_col, 'first_dept_store_year']

        print(f"    Number of treated units: {len(treatment_timing)}")
        print(f"    Treatment year range: {treatment_timing['first_dept_store_year'].min():.0f} - {treatment_timing['first_dept_store_year'].max():.0f}")

        # Distribution of treatment timing
        print("\n    Treatment timing distribution:")
        timing_dist = treatment_timing['first_dept_store_year'].value_counts().sort_index()
        for yr, cnt in timing_dist.items():
            print(f"        {int(yr)}: {cnt} counties")

        results['treatment_timing'] = treatment_timing
        results['treatment_geo_col'] = geo_col
        results['treatment_year_col'] = year_col

        # Save treatment timing
        save_table(treatment_timing, "treatment_timing", "First Department Store Opening by County")

        # Create visualization
        fig, axes = plt.subplots(1, 2, figsize=(14, 5))

        # Histogram of treatment timing
        axes[0].hist(treatment_timing['first_dept_store_year'], bins=30, edgecolor='black', alpha=0.7)
        axes[0].set_xlabel('Year of First Department Store Opening')
        axes[0].set_ylabel('Number of Counties')
        axes[0].set_title('Distribution of Treatment Timing')

        # Cumulative adoptions
        cumulative = timing_dist.sort_index().cumsum()
        axes[1].plot(cumulative.index, cumulative.values, marker='o', linewidth=2)
        axes[1].set_xlabel('Year')
        axes[1].set_ylabel('Cumulative Number of Treated Counties')
        axes[1].set_title('Cumulative Department Store Adoption')
        axes[1].grid(True, alpha=0.3)

        plt.tight_layout()
        save_figure(fig, "treatment_timing_distribution")

    else:
        print("    ERROR: Could not identify geographic or year columns")
        print(f"    Available columns: {list(dept_df.columns)}")

    return results

# =============================================================================
# SECTION 4: OCCUPATION CODE IDENTIFICATION
# =============================================================================

def identify_occupation_codes(results):
    """
    Examine occupation codes and identify displaced vs created occupations.

    Key occupation groups:
    - DISPLACED: Retail merchants, shopkeepers, peddlers, hucksters, local dealers
    - CREATED: Department store clerks, salespeople, retail employees
    """

    print("\n" + "="*80)
    print("SECTION 4: OCCUPATION CODE IDENTIFICATION")
    print("="*80)

    census_df = results['census']['data']
    census_meta = results['census']['meta']

    # -------------------------------------------------------------------------
    # 4.1 Find and examine occupation variables
    # -------------------------------------------------------------------------
    print("\n4.1 Occupation Variables in Census Data:")

    occ_cols = [c for c in census_df.columns if 'occ' in c.lower()]
    print(f"    Found columns: {occ_cols}")

    # Store occupation info
    occ_info = {}

    for occ_col in occ_cols:
        print(f"\n    Examining: {occ_col}")

        # Check for value labels
        if occ_col in census_meta.variable_value_labels:
            labels = census_meta.variable_value_labels[occ_col]
            occ_info[occ_col] = {
                'has_labels': True,
                'labels': labels,
                'n_codes': len(labels)
            }
            print(f"        Has value labels: Yes ({len(labels)} codes)")
        else:
            occ_info[occ_col] = {
                'has_labels': False,
                'labels': {},
                'n_codes': census_df[occ_col].nunique()
            }
            print(f"        Has value labels: No")
            print(f"        Unique values: {census_df[occ_col].nunique()}")

    # -------------------------------------------------------------------------
    # 4.2 Full occupation code listing
    # -------------------------------------------------------------------------
    print("\n4.2 Full Occupation Code Listing:")

    # Find the main occupation variable (usually occ1950 or similar IPUMS codes)
    main_occ_col = None
    for preferred in ['occ1950', 'occ', 'occstr', 'occupation']:
        if preferred in [c.lower() for c in occ_cols]:
            main_occ_col = [c for c in occ_cols if c.lower() == preferred][0]
            break

    if main_occ_col is None and occ_cols:
        main_occ_col = occ_cols[0]

    if main_occ_col and main_occ_col in census_meta.variable_value_labels:
        labels = census_meta.variable_value_labels[main_occ_col]

        # Create full occupation listing
        occ_listing = []
        for code, label in sorted(labels.items()):
            count = (census_df[main_occ_col] == code).sum()
            occ_listing.append({
                'Code': code,
                'Label': label,
                'Count': count,
                'Percent': count / len(census_df) * 100
            })

        occ_listing_df = pd.DataFrame(occ_listing)
        occ_listing_df = occ_listing_df.sort_values('Count', ascending=False)

        print(f"\n    Main occupation variable: {main_occ_col}")
        print(f"    Total unique codes: {len(labels)}")
        print("\n    Top 30 occupations by frequency:")
        print(tabulate(occ_listing_df.head(30), headers='keys', tablefmt='simple', showindex=False))

        # Save full listing
        save_table(occ_listing_df, "occupation_codes_full", f"Full Occupation Code Listing ({main_occ_col})")

        results['main_occ_col'] = main_occ_col
        results['occ_labels'] = labels
        results['occ_listing'] = occ_listing_df

    # -------------------------------------------------------------------------
    # 4.3 Identify DISPLACED occupations
    # -------------------------------------------------------------------------
    print("\n" + "-"*80)
    print("4.3 DISPLACED OCCUPATIONS (Likely negatively affected by department stores)")
    print("-"*80)

    # Keywords for displaced occupations
    displaced_keywords = [
        'merchant', 'shopkeeper', 'store owner', 'proprietor',
        'peddler', 'huckster', 'hawker', 'vendor', 'street',
        'dealer', 'trader', 'grocer', 'dry goods', 'general store',
        'retail trade', 'small business', 'shop owner'
    ]

    # IPUMS OCC1950 codes commonly associated with displaced workers
    # Based on historical occupation coding:
    displaced_occ_codes_1950 = {
        # Retail proprietors and managers (excluding large stores)
        250: "Buyers and department heads, store",
        260: "Floormen and floor managers, store",
        270: "Inspectors, scalers, and graders, log and lumber",
        280: "Managers and superintendents, building",
        # Merchants and dealers
        450: "Agents, n.e.c.",
        470: "Attendants and assistants, library",
        480: "Attendants, physicians and dentists office",
        # Self-employed retail
        980: "Keeps, operators, and managers, n.e.c.",
        # Peddlers and hucksters
        144: "Hucksters and peddlers",
        # Retail dealers
        290: "Buyers and shippers, farm products",
    }

    displaced_occupations = []

    if 'occ_labels' in results:
        labels = results['occ_labels']

        print("\n    Searching for displaced occupation codes...")
        print("    Keywords: ", displaced_keywords[:5], "...")

        for code, label in labels.items():
            label_lower = label.lower()
            matched = False
            matched_keyword = ""

            for keyword in displaced_keywords:
                if keyword in label_lower:
                    matched = True
                    matched_keyword = keyword
                    break

            if matched or code in displaced_occ_codes_1950:
                count = (census_df[main_occ_col] == code).sum()
                displaced_occupations.append({
                    'Code': code,
                    'Label': label,
                    'Count': count,
                    'Matched_Keyword': matched_keyword if matched else 'Manual code',
                    'Classification': 'DISPLACED'
                })

        displaced_df = pd.DataFrame(displaced_occupations)
        if len(displaced_df) > 0:
            displaced_df = displaced_df.sort_values('Count', ascending=False)
            print("\n    Identified Displaced Occupations:")
            print(tabulate(displaced_df, headers='keys', tablefmt='simple', showindex=False))
            save_table(displaced_df, "displaced_occupations", "Occupations Likely Displaced by Department Stores")
        else:
            print("    No displaced occupations found with current keywords.")
            print("    Consider examining occupation labels manually.")

    # -------------------------------------------------------------------------
    # 4.4 Identify CREATED occupations
    # -------------------------------------------------------------------------
    print("\n" + "-"*80)
    print("4.4 CREATED OCCUPATIONS (Likely created/expanded by department stores)")
    print("-"*80)

    # Keywords for created occupations
    created_keywords = [
        'clerk', 'sales', 'salesman', 'saleswoman', 'salesperson',
        'cashier', 'store', 'retail', 'department',
        'floorwalker', 'buyer', 'window dresser', 'display',
        'stock', 'wrapper', 'elevator operator', 'delivery'
    ]

    # IPUMS OCC1950 codes for department store workers
    created_occ_codes_1950 = {
        # Sales workers
        490: "Salesmen and sales clerks, n.e.c.",
        480: "Sales workers, retail",
        # Clerical
        350: "Stenographers, typists, and secretaries",
        360: "Stock clerks and storekeepers",
        370: "Typists",
        # Service workers in retail
        770: "Counter and fountain workers",
        # Department store specific
        250: "Buyers and department heads, store",
        260: "Floormen and floor managers, store",
    }

    created_occupations = []

    if 'occ_labels' in results:
        labels = results['occ_labels']

        print("\n    Searching for created occupation codes...")
        print("    Keywords: ", created_keywords[:5], "...")

        for code, label in labels.items():
            label_lower = label.lower()
            matched = False
            matched_keyword = ""

            for keyword in created_keywords:
                if keyword in label_lower:
                    matched = True
                    matched_keyword = keyword
                    break

            if matched or code in created_occ_codes_1950:
                count = (census_df[main_occ_col] == code).sum()
                created_occupations.append({
                    'Code': code,
                    'Label': label,
                    'Count': count,
                    'Matched_Keyword': matched_keyword if matched else 'Manual code',
                    'Classification': 'CREATED'
                })

        created_df = pd.DataFrame(created_occupations)
        if len(created_df) > 0:
            created_df = created_df.sort_values('Count', ascending=False)
            print("\n    Identified Created Occupations:")
            print(tabulate(created_df, headers='keys', tablefmt='simple', showindex=False))
            save_table(created_df, "created_occupations", "Occupations Likely Created by Department Stores")
        else:
            print("    No created occupations found with current keywords.")

    # -------------------------------------------------------------------------
    # 4.5 Create indicator variables
    # -------------------------------------------------------------------------
    print("\n" + "-"*80)
    print("4.5 Creating Occupation Indicator Variables")
    print("-"*80)

    if main_occ_col:
        # Displaced occupation indicator
        displaced_codes = [occ['Code'] for occ in displaced_occupations] if displaced_occupations else []
        census_df['occ_displaced'] = census_df[main_occ_col].isin(displaced_codes).astype(int)

        # Created occupation indicator
        created_codes = [occ['Code'] for occ in created_occupations] if created_occupations else []
        census_df['occ_created'] = census_df[main_occ_col].isin(created_codes).astype(int)

        print(f"\n    Created indicator: occ_displaced")
        print(f"        Codes included: {displaced_codes}")
        print(f"        N=1: {census_df['occ_displaced'].sum():,}")
        print(f"        N=0: {(census_df['occ_displaced'] == 0).sum():,}")

        print(f"\n    Created indicator: occ_created")
        print(f"        Codes included: {created_codes}")
        print(f"        N=1: {census_df['occ_created'].sum():,}")
        print(f"        N=0: {(census_df['occ_created'] == 0).sum():,}")

        # Update results
        results['census']['data'] = census_df
        results['displaced_codes'] = displaced_codes
        results['created_codes'] = created_codes

    # -------------------------------------------------------------------------
    # 4.6 Occupation distributions over time
    # -------------------------------------------------------------------------
    print("\n" + "-"*80)
    print("4.6 Occupation Frequency Distributions Over Time")
    print("-"*80)

    year_col = results['key_vars']['census_year'][0] if results['key_vars']['census_year'] else None

    if year_col and main_occ_col:
        # Distribution of displaced occupations over time
        if displaced_codes:
            displaced_by_year = census_df.groupby(year_col)['occ_displaced'].agg(['sum', 'mean', 'count'])
            displaced_by_year.columns = ['N_Displaced', 'Pct_Displaced', 'Total_N']
            displaced_by_year['Pct_Displaced'] = displaced_by_year['Pct_Displaced'] * 100

            print("\n    Displaced Occupations by Year:")
            print(tabulate(displaced_by_year, headers='keys', tablefmt='simple'))
            save_table(displaced_by_year.reset_index(), "displaced_by_year", "Displaced Occupations Over Time")

        # Distribution of created occupations over time
        if created_codes:
            created_by_year = census_df.groupby(year_col)['occ_created'].agg(['sum', 'mean', 'count'])
            created_by_year.columns = ['N_Created', 'Pct_Created', 'Total_N']
            created_by_year['Pct_Created'] = created_by_year['Pct_Created'] * 100

            print("\n    Created Occupations by Year:")
            print(tabulate(created_by_year, headers='keys', tablefmt='simple'))
            save_table(created_by_year.reset_index(), "created_by_year", "Created Occupations Over Time")

        # Visualization
        fig, axes = plt.subplots(1, 2, figsize=(14, 5))

        if displaced_codes:
            axes[0].bar(displaced_by_year.index, displaced_by_year['Pct_Displaced'], alpha=0.7, color='red')
            axes[0].set_xlabel('Year')
            axes[0].set_ylabel('Percentage')
            axes[0].set_title('Share in Displaced Occupations Over Time')
            axes[0].grid(True, alpha=0.3)

        if created_codes:
            axes[1].bar(created_by_year.index, created_by_year['Pct_Created'], alpha=0.7, color='green')
            axes[1].set_xlabel('Year')
            axes[1].set_ylabel('Percentage')
            axes[1].set_title('Share in Created Occupations Over Time')
            axes[1].grid(True, alpha=0.3)

        plt.tight_layout()
        save_figure(fig, "occupation_distributions_over_time")

    # Store classification documentation
    classification_doc = {
        'displaced_keywords': displaced_keywords,
        'created_keywords': created_keywords,
        'displaced_occupations': displaced_occupations,
        'created_occupations': created_occupations
    }
    results['occupation_classification'] = classification_doc

    return results

# =============================================================================
# SECTION 5: MERGE DATASETS AND SHOW TREATMENT VARIATION
# =============================================================================

def merge_datasets(results):
    """Merge census and department store data, show treatment timing variation."""

    print("\n" + "="*80)
    print("SECTION 5: MERGING DATASETS")
    print("="*80)

    census_df = results['census']['data'].copy()

    if 'treatment_timing' not in results:
        print("    ERROR: Treatment timing not created. Run Section 3 first.")
        return results

    treatment_df = results['treatment_timing']
    geo_col = results['treatment_geo_col']

    # Find matching geographic variable in census
    census_geo_cols = results['key_vars']['census_geo']

    print(f"\n5.1 Identifying Merge Keys:")
    print(f"    Department store geographic variable: {geo_col}")
    print(f"    Census geographic variables: {census_geo_cols}")

    # Try to find matching column
    merge_col = None
    for cc in census_geo_cols:
        if cc.lower() == geo_col.lower():
            merge_col = cc
            break
        # Check for similar naming
        if 'county' in cc.lower() and 'county' in geo_col.lower():
            merge_col = cc
            break
        if 'fips' in cc.lower() and 'fips' in geo_col.lower():
            merge_col = cc
            break

    if merge_col is None:
        print(f"\n    WARNING: Could not automatically identify merge key.")
        print(f"    Will try matching on: {census_geo_cols[0] if census_geo_cols else 'N/A'}")
        merge_col = census_geo_cols[0] if census_geo_cols else None

    if merge_col:
        print(f"\n5.2 Merging on: {merge_col}")

        # Standardize the merge key name
        treatment_df_renamed = treatment_df.rename(columns={geo_col: merge_col})

        # Merge
        merged_df = census_df.merge(
            treatment_df_renamed,
            on=merge_col,
            how='left'
        )

        print(f"\n    Merge Results:")
        print(f"        Census observations: {len(census_df):,}")
        print(f"        Matched to treatment: {merged_df['first_dept_store_year'].notna().sum():,}")
        print(f"        Unmatched (control): {merged_df['first_dept_store_year'].isna().sum():,}")

        # Create treatment indicators
        year_col = results['key_vars']['census_year'][0] if results['key_vars']['census_year'] else None

        if year_col:
            # Ever treated indicator
            merged_df['ever_treated'] = merged_df['first_dept_store_year'].notna().astype(int)

            # Currently treated indicator (post-treatment)
            merged_df['treated'] = (
                (merged_df['first_dept_store_year'].notna()) &
                (merged_df[year_col] >= merged_df['first_dept_store_year'])
            ).astype(int)

            # Years relative to treatment
            merged_df['event_time'] = merged_df[year_col] - merged_df['first_dept_store_year']

            print(f"\n5.3 Treatment Variable Summary:")
            print(f"    ever_treated=1: {merged_df['ever_treated'].sum():,}")
            print(f"    ever_treated=0: {(merged_df['ever_treated'] == 0).sum():,}")
            print(f"\n    treated (post-treatment)=1: {merged_df['treated'].sum():,}")
            print(f"    treated (post-treatment)=0: {(merged_df['treated'] == 0).sum():,}")

        # Treatment timing variation
        print("\n5.4 Treatment Timing Variation:")
        if 'first_dept_store_year' in merged_df.columns:
            timing_var = merged_df[merged_df['ever_treated'] == 1]['first_dept_store_year'].value_counts().sort_index()
            print("\n    Number of individuals by treatment cohort year:")
            for yr, cnt in timing_var.head(15).items():
                print(f"        {int(yr)}: {cnt:,}")

            # Visualization
            fig, ax = plt.subplots(figsize=(12, 6))
            timing_var.plot(kind='bar', ax=ax, alpha=0.7)
            ax.set_xlabel('First Department Store Opening Year')
            ax.set_ylabel('Number of Census Observations')
            ax.set_title('Treatment Cohort Sizes (Staggered DiD)')
            plt.xticks(rotation=45)
            plt.tight_layout()
            save_figure(fig, "treatment_cohort_sizes")

        results['merged_data'] = merged_df

        # Save merged dataset summary
        merge_summary = pd.DataFrame({
            'Metric': ['Census Observations', 'Matched to Treatment', 'Control (Never Treated)',
                      'Currently Treated', 'Not Yet Treated'],
            'N': [len(census_df),
                  merged_df['first_dept_store_year'].notna().sum(),
                  merged_df['first_dept_store_year'].isna().sum(),
                  merged_df['treated'].sum() if 'treated' in merged_df.columns else 'N/A',
                  (merged_df['ever_treated'] - merged_df['treated']).sum() if 'treated' in merged_df.columns else 'N/A']
        })
        save_table(merge_summary, "merge_summary", "Dataset Merge Summary")

    return results

# =============================================================================
# SECTION 6: CREATE CODEBOOK
# =============================================================================

def create_codebook(results):
    """Create comprehensive codebook documenting all variables."""

    print("\n" + "="*80)
    print("SECTION 6: CREATING CODEBOOK")
    print("="*80)

    codebook_path = os.path.join(OUTPUT_DIR, "codebooks", "codebook.txt")

    with open(codebook_path, 'w') as f:
        f.write("="*80 + "\n")
        f.write("CODEBOOK: Department Store Labor Market Impact Analysis\n")
        f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("="*80 + "\n\n")

        # Section 1: Data Sources
        f.write("1. DATA SOURCES\n")
        f.write("-"*40 + "\n\n")
        f.write(f"Census Data: {CENSUS_DATA_PATH}\n")
        f.write(f"  - Observations: {results['census']['n_obs']:,}\n")
        f.write(f"  - Variables: {results['census']['n_vars']}\n\n")
        f.write(f"Department Store Data: {DEPT_STORE_PATH}\n")
        f.write(f"  - Observations: {results['dept_store']['n_obs']:,}\n")
        f.write(f"  - Variables: {results['dept_store']['n_vars']}\n\n")

        # Section 2: Key Variables
        f.write("\n2. KEY VARIABLES\n")
        f.write("-"*40 + "\n\n")
        f.write("Geographic Identifiers:\n")
        f.write(f"  Census: {results['key_vars']['census_geo']}\n")
        f.write(f"  Dept Store: {results['key_vars']['dept_geo']}\n\n")
        f.write("Year Variables:\n")
        f.write(f"  Census: {results['key_vars']['census_year']}\n")
        f.write(f"  Dept Store: {results['key_vars']['dept_year']}\n\n")

        # Section 3: Treatment Variables
        f.write("\n3. TREATMENT VARIABLES\n")
        f.write("-"*40 + "\n\n")
        f.write("first_dept_store_year: Year when county first received a department store\n")
        f.write("  - Source: Derived from department store opening data\n")
        f.write("  - Missing for never-treated counties\n\n")
        f.write("ever_treated: Binary indicator for counties that ever receive treatment\n")
        f.write("  - 1 = County receives department store at some point\n")
        f.write("  - 0 = County never receives department store (control)\n\n")
        f.write("treated: Binary indicator for post-treatment status\n")
        f.write("  - 1 = Observation is in treated county AND in/after treatment year\n")
        f.write("  - 0 = Otherwise (control or pre-treatment)\n\n")
        f.write("event_time: Years relative to treatment\n")
        f.write("  - Negative = Years before treatment\n")
        f.write("  - 0 = Treatment year\n")
        f.write("  - Positive = Years after treatment\n")
        f.write("  - Missing for never-treated counties\n\n")

        # Section 4: Occupation Classification
        f.write("\n4. OCCUPATION CLASSIFICATION\n")
        f.write("-"*40 + "\n\n")

        if 'occupation_classification' in results:
            occ_class = results['occupation_classification']

            f.write("DISPLACED OCCUPATIONS (occ_displaced=1)\n")
            f.write("Definition: Occupations likely negatively affected by department stores\n")
            f.write("Keywords used: " + ", ".join(occ_class['displaced_keywords'][:10]) + "...\n")
            f.write("Codes included:\n")
            for occ in occ_class['displaced_occupations'][:20]:
                f.write(f"  {occ['Code']}: {occ['Label']}\n")
            f.write("\n")

            f.write("CREATED OCCUPATIONS (occ_created=1)\n")
            f.write("Definition: Occupations likely created/expanded by department stores\n")
            f.write("Keywords used: " + ", ".join(occ_class['created_keywords'][:10]) + "...\n")
            f.write("Codes included:\n")
            for occ in occ_class['created_occupations'][:20]:
                f.write(f"  {occ['Code']}: {occ['Label']}\n")

        f.write("\n\n5. NOTES AND METHODOLOGY\n")
        f.write("-"*40 + "\n\n")
        f.write("Staggered Difference-in-Differences Design:\n")
        f.write("  - Treatment: First department store opening in county\n")
        f.write("  - Timing: Varies across counties (staggered adoption)\n")
        f.write("  - Control: Counties that never receive department stores\n")
        f.write("  - Estimation: Suitable for Callaway-Sant'Anna or Sun-Abraham estimators\n")

    print(f"    Codebook saved to: {codebook_path}")

    return results

# =============================================================================
# SECTION 7: SUMMARY STATISTICS
# =============================================================================

def generate_summary_statistics(results):
    """Generate comprehensive summary statistics tables."""

    print("\n" + "="*80)
    print("SECTION 7: GENERATING SUMMARY STATISTICS")
    print("="*80)

    if 'merged_data' not in results:
        print("    ERROR: Merged data not available. Run Section 5 first.")
        return results

    df = results['merged_data']
    year_col = results['key_vars']['census_year'][0] if results['key_vars']['census_year'] else None

    # -------------------------------------------------------------------------
    # 7.1 Pre-treatment characteristics by treatment status
    # -------------------------------------------------------------------------
    print("\n7.1 Pre-Treatment Characteristics by Treatment Status:")

    if 'first_dept_store_year' in df.columns and year_col:
        # Define pre-treatment period (observations before treatment)
        pre_treatment = df[
            (df['ever_treated'] == 0) |  # Never treated
            ((df['ever_treated'] == 1) & (df[year_col] < df['first_dept_store_year']))  # Treated but pre-period
        ].copy()

        # Identify numeric variables for summary
        numeric_vars = df.select_dtypes(include=[np.number]).columns.tolist()
        outcome_vars = [v for v in numeric_vars if v not in [
            'first_dept_store_year', 'ever_treated', 'treated', 'event_time'
        ]][:15]  # Limit to 15 variables

        if outcome_vars:
            summary_stats = []

            for var in outcome_vars:
                treated_vals = pre_treatment[pre_treatment['ever_treated'] == 1][var].dropna()
                control_vals = pre_treatment[pre_treatment['ever_treated'] == 0][var].dropna()

                summary_stats.append({
                    'Variable': var,
                    'Treated_Mean': treated_vals.mean(),
                    'Treated_SD': treated_vals.std(),
                    'Control_Mean': control_vals.mean(),
                    'Control_SD': control_vals.std(),
                    'Difference': treated_vals.mean() - control_vals.mean(),
                    'Treated_N': len(treated_vals),
                    'Control_N': len(control_vals)
                })

            summary_df = pd.DataFrame(summary_stats)
            print(tabulate(summary_df, headers='keys', tablefmt='simple', showindex=False, floatfmt='.3f'))
            save_table(summary_df, "pretreatment_balance", "Pre-Treatment Characteristics by Treatment Status")

    # -------------------------------------------------------------------------
    # 7.2 Outcome variables summary
    # -------------------------------------------------------------------------
    print("\n7.2 Outcome Variables Summary:")

    # Look for common outcome variables
    outcome_candidates = ['occ_displaced', 'occ_created', 'labforce', 'employed',
                         'married', 'marst', 'incwage', 'wage', 'sei', 'occscore']

    available_outcomes = [v for v in outcome_candidates if v in df.columns]

    if available_outcomes:
        outcome_summary = df[available_outcomes].describe()
        print(tabulate(outcome_summary, headers='keys', tablefmt='simple', floatfmt='.3f'))
        save_table(outcome_summary, "outcome_summary", "Outcome Variables Summary Statistics")

    # -------------------------------------------------------------------------
    # 7.3 Occupation distribution summary
    # -------------------------------------------------------------------------
    print("\n7.3 Occupation Distribution Summary:")

    if 'occ_displaced' in df.columns and 'occ_created' in df.columns:
        occ_dist = df.groupby('ever_treated').agg({
            'occ_displaced': ['sum', 'mean'],
            'occ_created': ['sum', 'mean']
        }).round(4)

        print("\n    By Treatment Status:")
        print(tabulate(occ_dist, headers='keys', tablefmt='simple'))

        if year_col:
            occ_time = df.groupby([year_col, 'ever_treated']).agg({
                'occ_displaced': 'mean',
                'occ_created': 'mean'
            }).unstack()

            print("\n    By Year and Treatment Status:")
            print(tabulate(occ_time, headers='keys', tablefmt='simple', floatfmt='.4f'))
            save_table(occ_time.reset_index(), "occupation_by_year_treatment",
                      "Occupation Distribution by Year and Treatment Status")

    # -------------------------------------------------------------------------
    # 7.4 Sample size by treatment cohort and year
    # -------------------------------------------------------------------------
    print("\n7.4 Sample Size by Treatment Cohort and Census Year:")

    if 'first_dept_store_year' in df.columns and year_col:
        cohort_year = df.groupby(['first_dept_store_year', year_col]).size().unstack(fill_value=0)
        print(tabulate(cohort_year.head(10), headers='keys', tablefmt='simple'))
        save_table(cohort_year, "sample_by_cohort_year", "Sample Size by Treatment Cohort and Year")

    return results

# =============================================================================
# SECTION 8: VISUALIZATIONS
# =============================================================================

def create_visualizations(results):
    """Create visualizations for the analysis."""

    print("\n" + "="*80)
    print("SECTION 8: CREATING VISUALIZATIONS")
    print("="*80)

    if 'merged_data' not in results:
        print("    ERROR: Merged data not available.")
        return results

    df = results['merged_data']
    year_col = results['key_vars']['census_year'][0] if results['key_vars']['census_year'] else None

    # Set style
    plt.style.use('seaborn-v0_8-whitegrid')

    # -------------------------------------------------------------------------
    # 8.1 Department Store Adoption Over Time
    # -------------------------------------------------------------------------
    print("\n8.1 Department Store Adoption Over Time:")

    if 'treatment_timing' in results:
        treatment_df = results['treatment_timing']

        fig, axes = plt.subplots(2, 2, figsize=(14, 10))

        # Histogram of first openings
        axes[0, 0].hist(treatment_df['first_dept_store_year'], bins=30, edgecolor='black', alpha=0.7)
        axes[0, 0].set_xlabel('Year')
        axes[0, 0].set_ylabel('Number of Counties')
        axes[0, 0].set_title('Distribution of First Department Store Openings')

        # Cumulative adoption
        timing_dist = treatment_df['first_dept_store_year'].value_counts().sort_index().cumsum()
        axes[0, 1].plot(timing_dist.index, timing_dist.values, marker='o', linewidth=2, markersize=3)
        axes[0, 1].set_xlabel('Year')
        axes[0, 1].set_ylabel('Cumulative Number of Counties')
        axes[0, 1].set_title('Cumulative Department Store Adoption')
        axes[0, 1].grid(True, alpha=0.3)

        # Treatment status over time in census
        if year_col and 'treated' in df.columns:
            treat_by_year = df.groupby(year_col)['treated'].mean() * 100
            axes[1, 0].bar(treat_by_year.index, treat_by_year.values, alpha=0.7, color='green')
            axes[1, 0].set_xlabel('Census Year')
            axes[1, 0].set_ylabel('Percent Treated')
            axes[1, 0].set_title('Share of Census Sample in Treated Counties (Post-Treatment)')

        # Ever treated share
        if year_col and 'ever_treated' in df.columns:
            ever_by_year = df.groupby(year_col)['ever_treated'].mean() * 100
            axes[1, 1].bar(ever_by_year.index, ever_by_year.values, alpha=0.7, color='blue')
            axes[1, 1].set_xlabel('Census Year')
            axes[1, 1].set_ylabel('Percent')
            axes[1, 1].set_title('Share in Counties That Will Ever Be Treated')

        plt.tight_layout()
        save_figure(fig, "adoption_over_time")

    # -------------------------------------------------------------------------
    # 8.2 Pre-Trends in Key Outcomes
    # -------------------------------------------------------------------------
    print("\n8.2 Pre-Trends in Key Outcomes:")

    if year_col and 'ever_treated' in df.columns:
        fig, axes = plt.subplots(2, 2, figsize=(14, 10))

        outcomes = ['occ_displaced', 'occ_created']
        available_outcomes = [o for o in outcomes if o in df.columns]

        for i, outcome in enumerate(available_outcomes[:2]):
            ax = axes[i // 2, i % 2] if len(available_outcomes) > 1 else axes[0, 0]

            # Calculate means by year and treatment status
            trends = df.groupby([year_col, 'ever_treated'])[outcome].mean().unstack()

            if 0 in trends.columns:
                ax.plot(trends.index, trends[0], marker='o', label='Never Treated', linewidth=2)
            if 1 in trends.columns:
                ax.plot(trends.index, trends[1], marker='s', label='Ever Treated', linewidth=2)

            ax.set_xlabel('Census Year')
            ax.set_ylabel(f'Share in {outcome}')
            ax.set_title(f'Pre-Trends: {outcome}')
            ax.legend()
            ax.grid(True, alpha=0.3)

        # Add placeholders for remaining subplots if needed
        if len(available_outcomes) < 4:
            for j in range(len(available_outcomes), 4):
                axes[j // 2, j % 2].text(0.5, 0.5, 'No data available',
                                         ha='center', va='center', fontsize=12)
                axes[j // 2, j % 2].set_visible(False)

        plt.tight_layout()
        save_figure(fig, "pretrends")

    # -------------------------------------------------------------------------
    # 8.3 Event Study Plot
    # -------------------------------------------------------------------------
    print("\n8.3 Event Study Preparation:")

    if 'event_time' in df.columns:
        # Calculate outcome means by event time
        fig, axes = plt.subplots(1, 2, figsize=(14, 5))

        for i, outcome in enumerate(['occ_displaced', 'occ_created'][:2]):
            if outcome in df.columns:
                event_means = df[df['ever_treated'] == 1].groupby('event_time')[outcome].agg(['mean', 'std', 'count'])
                event_means['se'] = event_means['std'] / np.sqrt(event_means['count'])

                # Limit to reasonable event window
                event_means = event_means[(event_means.index >= -20) & (event_means.index <= 20)]

                axes[i].errorbar(event_means.index, event_means['mean'],
                               yerr=1.96 * event_means['se'],
                               marker='o', capsize=3, linewidth=1, markersize=4)
                axes[i].axvline(x=0, color='red', linestyle='--', alpha=0.7, label='Treatment')
                axes[i].set_xlabel('Years Relative to Treatment')
                axes[i].set_ylabel(f'Mean {outcome}')
                axes[i].set_title(f'Event Study: {outcome}')
                axes[i].legend()
                axes[i].grid(True, alpha=0.3)

        plt.tight_layout()
        save_figure(fig, "event_study_raw")

    # -------------------------------------------------------------------------
    # 8.4 Occupation Composition Changes
    # -------------------------------------------------------------------------
    print("\n8.4 Occupation Composition Changes Over Time:")

    if year_col and 'ever_treated' in df.columns:
        fig, axes = plt.subplots(1, 2, figsize=(14, 5))

        # Displaced occupations
        if 'occ_displaced' in df.columns:
            pivot = df.groupby([year_col, 'ever_treated'])['occ_displaced'].mean().unstack() * 100
            pivot.plot(ax=axes[0], marker='o', linewidth=2)
            axes[0].set_xlabel('Census Year')
            axes[0].set_ylabel('Percent in Displaced Occupations')
            axes[0].set_title('Displaced Occupations by Treatment Status')
            axes[0].legend(['Never Treated', 'Ever Treated'])
            axes[0].grid(True, alpha=0.3)

        # Created occupations
        if 'occ_created' in df.columns:
            pivot = df.groupby([year_col, 'ever_treated'])['occ_created'].mean().unstack() * 100
            pivot.plot(ax=axes[1], marker='o', linewidth=2)
            axes[1].set_xlabel('Census Year')
            axes[1].set_ylabel('Percent in Created Occupations')
            axes[1].set_title('Created Occupations by Treatment Status')
            axes[1].legend(['Never Treated', 'Ever Treated'])
            axes[1].grid(True, alpha=0.3)

        plt.tight_layout()
        save_figure(fig, "occupation_composition_changes")

    print("\n    All visualizations saved to: " + os.path.join(OUTPUT_DIR, "figures"))

    return results

# =============================================================================
# MAIN EXECUTION
# =============================================================================

def main():
    """Main execution function."""

    print("\n" + "#"*80)
    print("#" + " "*78 + "#")
    print("#" + "  DEPARTMENT STORE LABOR MARKET IMPACT ANALYSIS  ".center(78) + "#")
    print("#" + "  Staggered Difference-in-Differences  ".center(78) + "#")
    print("#" + " "*78 + "#")
    print("#"*80)

    print(f"\nStart time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"\nConfiguration:")
    print(f"  Base path: {BASE_PATH}")
    print(f"  Census data: {CENSUS_DATA_PATH}")
    print(f"  Dept store data: {DEPT_STORE_PATH}")
    print(f"  Output directory: {OUTPUT_DIR}")

    # Create output directories
    create_output_dirs()

    # Run analysis pipeline
    results = {}

    # Section 1: Load and describe data
    results = load_and_describe_data()

    # Section 2: Identify key variables
    results = identify_key_variables(results)

    # Section 3: Create treatment variable
    results = create_treatment_variable(results)

    # Section 4: Occupation code identification
    results = identify_occupation_codes(results)

    # Section 5: Merge datasets
    results = merge_datasets(results)

    # Section 6: Create codebook
    results = create_codebook(results)

    # Section 7: Summary statistics
    results = generate_summary_statistics(results)

    # Section 8: Visualizations
    results = create_visualizations(results)

    # Final summary
    print("\n" + "="*80)
    print("ANALYSIS COMPLETE")
    print("="*80)
    print(f"\nEnd time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"\nOutputs saved to: {OUTPUT_DIR}")
    print("  - tables/: CSV and formatted text tables")
    print("  - figures/: PNG visualizations")
    print("  - codebooks/: Variable documentation")

    # Save merged data for further analysis
    if 'merged_data' in results:
        merged_path = os.path.join(OUTPUT_DIR, "data", "merged_analysis_data.csv")
        results['merged_data'].to_csv(merged_path, index=False)
        print(f"\n  Merged dataset saved: {merged_path}")

    return results

if __name__ == "__main__":
    results = main()
