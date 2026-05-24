import pandas as pd

# Load clean data
df = pd.read_csv('data.csv', encoding='latin1')
df = df.dropna(subset=['CustomerID'])
df = df[df['Quantity'] > 0]
df = df[df['UnitPrice'] > 0]
df = df[~df['InvoiceNo'].astype(str).str.startswith('C')]

df['Revenue'] = df['Quantity'] * df['UnitPrice']
df['InvoiceDate'] = pd.to_datetime(df['InvoiceDate'])
df['Month'] = df['InvoiceDate'].dt.to_period('M').astype(str)
df['Hour'] = df['InvoiceDate'].dt.hour
df['DayOfWeek'] = df['InvoiceDate'].dt.day_name()
df['Date'] = df['InvoiceDate'].dt.date

# RFM
snapshot = df['Date'].max()
rfm = df.groupby('CustomerID').agg({
    'Date': lambda x: (snapshot - x.max()).days,
    'InvoiceNo': 'nunique',
    'Revenue': 'sum'
}).reset_index()
rfm.columns = ['CustomerID', 'Recency', 'Frequency', 'Monetary']
rfm['R'] = pd.qcut(rfm['Recency'], 5, labels=[5,4,3,2,1])
rfm['F'] = pd.qcut(rfm['Frequency'].rank(method='first'), 5, labels=[1,2,3,4,5])
rfm['M'] = pd.qcut(rfm['Monetary'], 5, labels=[1,2,3,4,5])
rfm['RFM_Score'] = rfm['R'].astype(int) + rfm['F'].astype(int) + rfm['M'].astype(int)

def segment(score):
    if score >= 13: return 'Champions'
    elif score >= 10: return 'Loyal'
    elif score >= 7: return 'Potential'
    elif score >= 5: return 'At Risk'
    else: return 'Lost'

rfm['Segment'] = rfm['RFM_Score'].apply(segment)

# Export main data
df.to_csv('ecommerce_powerbi.csv', index=False)
print(f"✅ ecommerce_powerbi.csv — {len(df):,} rows")

# Export RFM
rfm.to_csv('rfm_segments.csv', index=False)
print(f"✅ rfm_segments.csv — {len(rfm):,} rows")

# Export monthly summary
monthly = df.groupby('Month').agg(
    Orders=('InvoiceNo', 'nunique'),
    Customers=('CustomerID', 'nunique'),
    Revenue=('Revenue', 'sum')
).reset_index()
monthly.to_csv('monthly_summary.csv', index=False)
print(f"✅ monthly_summary.csv — {len(monthly):,} rows")

print("\n✅ All files exported for Power BI!")