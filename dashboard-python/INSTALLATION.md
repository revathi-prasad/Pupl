# Pupl Dashboard Installation Guide

## Quick Start

The dashboard has been successfully tested and is ready to run. Follow these steps to launch the dashboard locally:

### 1. Navigate to Dashboard Directory
```bash
cd /Users/revathiprasad/Documents/GitHub/Pupl/PupillometryApp/dashboard-python
```

### 2. Launch the Dashboard
```bash
streamlit run app.py
```

The dashboard will automatically open in your browser at `http://localhost:8501`

## Installation Issues & Solutions

### PyArrow Installation Problem (macOS)

**Problem**: Building wheel for pyarrow failed with compilation errors

**Solution Applied**:
1. Upgrade pip and build tools:
   ```bash
   python -m pip install --upgrade pip setuptools wheel
   ```

2. Install specific PyArrow version first:
   ```bash
   python -m pip install pyarrow==9.0.0
   ```

3. Then install Streamlit:
   ```bash
   python -m pip install streamlit
   ```

## Verified Dependencies

The following packages are confirmed working:
- `streamlit>=1.28.0` ✅
- `pandas>=1.5.0` ✅  
- `plotly>=5.15.0` ✅
- `scipy>=1.10.0` ✅
- `numpy>=1.24.0` ✅
- `pyarrow==9.0.0` ✅

## Dashboard Features

✅ **Hero Metrics Panel**: APEX attention score, attention span, cognitive load
✅ **Phase Analysis**: Calibration, Cognitive Task, Memory Assessment phases
✅ **Timeline Visualization**: Pupil diameter, phasic response, peak moments
✅ **Attention Funnel**: Impression → Viewable → Eyes-On → Engaged conversion
✅ **Business Metrics**: ROI analysis, traditional vs physiological comparison
✅ **Data Export**: CSV download functionality

## Test Results

Core metrics validation completed successfully:
- APEX score calculation: ~0.717-0.742 ✅
- Baseline comparison methods working ✅  
- Phase segmentation (3 phases detected) ✅
- Business metrics scaled appropriately ✅

## Data Source

Dashboard uses Firebase session data:
- Location: `../Firebase/Session_7_23_2025/`
- Session duration: 1.6 minutes
- ~2900 pupil measurements at 30Hz sampling rate

## Running the Dashboard

Once launched, the dashboard provides:
1. **Campaign Configuration**: Select demographics and content type
2. **Phase Analysis**: Focus on specific session phases or view complete timeline
3. **Real-time Metrics**: Live tracking simulation with 247 participants
4. **Business ROI**: Cost efficiency and accuracy improvements over traditional methods

## Troubleshooting

If you encounter any issues:
1. Ensure you're in the correct directory
2. Check that Firebase data is available at `../Firebase/Session_7_23_2025/`
3. Verify Python environment has all required packages
4. For PyArrow issues, use the specific version (9.0.0) as shown above

## Next Steps

🎯 **Priority Tasks**:
- Add YouTube video embed functionality to iOS app
- Implement full timeline with video markers  
- Enhance high-engagement period highlighting

The dashboard is now fully functional and ready for client/investor demonstrations.