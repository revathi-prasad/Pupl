"""
Data loading and preprocessing utilities for pupillometry dashboard
"""

import pandas as pd
import numpy as np
from pathlib import Path
from typing import Dict, Tuple, Optional
import json

def load_session_data(session_path: str) -> Dict[str, pd.DataFrame]:
    """
    Load all CSV files from a Firebase session export
    
    Args:
        session_path: Path to session folder (e.g., 'Firebase/Session_7_23_2025')
    
    Returns:
        Dictionary containing all loaded dataframes
    """
    session_dir = Path(session_path)
    data = {}
    
    # Load measurements.csv (main pupil data)
    measurements_file = session_dir / 'measurements.csv'
    if measurements_file.exists():
        data['measurements'] = pd.read_csv(measurements_file)
        print(f"✅ Loaded measurements: {len(data['measurements']):,} records")
    else:
        raise FileNotFoundError(f"measurements.csv not found in {session_path}")
    
    # Load events.csv (task events)
    events_file = session_dir / 'events.csv'
    if events_file.exists():
        data['events'] = pd.read_csv(events_file)
        print(f"✅ Loaded events: {len(data['events']):,} records")
    
    # Load facial_landmarks.csv (MediaPipe data)
    landmarks_file = session_dir / 'facial_landmarks.csv'
    if landmarks_file.exists():
        data['facial_landmarks'] = pd.read_csv(landmarks_file)
        print(f"✅ Loaded facial landmarks: {len(data['facial_landmarks']):,} records")
    
    # Load gradcpt_responses.csv (task responses)
    gradcpt_file = session_dir / 'gradcpt_responses.csv'
    if gradcpt_file.exists():
        data['gradcpt_responses'] = pd.read_csv(gradcpt_file)
        print(f"✅ Loaded GradCPT responses: {len(data['gradcpt_responses']):,} records")
    
    # Load performance_metrics.json
    metrics_file = session_dir / 'performance_metrics.json'
    if metrics_file.exists():
        with open(metrics_file, 'r') as f:
            data['performance_metrics'] = json.load(f)
        print(f"✅ Loaded performance metrics")
    
    return data

def preprocess_measurements(measurements_df: pd.DataFrame) -> pd.DataFrame:
    """
    Clean and preprocess pupil measurements data with enhanced content type support
    """
    df = measurements_df.copy()
    
    # Convert timestamp to relative time (minutes from start)
    start_time = df['timestamp'].min()
    df['time_minutes'] = (df['timestamp'] - start_time) / 60
    df['time_seconds'] = (df['timestamp'] - start_time)
    
    # Add measurement index for plotting
    df = df.reset_index(drop=True)
    df['measurement_index'] = df.index
    
    # Enhanced content type handling for backwards compatibility
    if 'contentType' not in df.columns:
        print("⚠️ Legacy data detected: Adding default content type mapping")
        # For backwards compatibility, assign phases based on time progression
        df['contentType'] = 'calibration'  # Default assignment
        print("📊 Content type column added for backwards compatibility")
    else:
        print(f"✅ Content type tracking detected: {df['contentType'].nunique()} unique content types")
    
    # Quality checks and filtering
    initial_count = len(df)
    
    # Remove measurements with invalid diameter values
    df = df[(df['diameterMM'] > 0.5) & (df['diameterMM'] < 10.0)]
    
    # Remove measurements with very low confidence (likely tracking failures)
    df = df[df['confidence'] > 0.1]
    
    # Handle outliers (values beyond 3 standard deviations)
    diameter_mean = df['diameterMM'].mean()
    diameter_std = df['diameterMM'].std()
    df = df[np.abs(df['diameterMM'] - diameter_mean) <= 3 * diameter_std]
    
    final_count = len(df)
    filtered_count = initial_count - final_count
    
    if filtered_count > 0:
        print(f"⚠️ Filtered out {filtered_count:,} measurements ({filtered_count/initial_count*100:.1f}%)")
    
    return df

def create_timeline_data(measurements_df: pd.DataFrame, events_df: Optional[pd.DataFrame] = None) -> Dict:
    """
    Create timeline data for visualization
    """
    df = measurements_df.copy()
    
    # Basic timeline data
    timeline_data = {
        'time_minutes': df['time_minutes'],
        'time_seconds': df['time_seconds'],
        'diameter_mm': df['diameterMM'],
        'confidence': df['confidence'],
        'center_x': df['centerX'],
        'center_y': df['centerY']
    }
    
    # Add events if available
    if events_df is not None and len(events_df) > 0:
        # Convert event timestamps to relative time
        start_time = measurements_df['timestamp'].min()
        events_timeline = []
        
        for _, event in events_df.iterrows():
            event_time_minutes = (event['timestamp'] - start_time) / 60
            event_time_seconds = event['timestamp'] - start_time
            
            # Parse event data
            event_data = {}
            if pd.notna(event['data']):
                for pair in str(event['data']).split(';'):
                    if ':' in pair:
                        key, value = pair.split(':', 1)
                        event_data[key] = value
            
            events_timeline.append({
                'timestamp': event['timestamp'],
                'time_minutes': event_time_minutes,
                'time_seconds': event_time_seconds,
                'type': event['type'],
                'data': event_data
            })
        
        timeline_data['events'] = events_timeline
    
    return timeline_data

def calculate_sampling_rate(measurements_df: pd.DataFrame) -> Dict:
    """
    Calculate actual sampling rate and timing statistics
    """
    timestamps = measurements_df['timestamp'].sort_values()
    time_diffs = timestamps.diff().dropna()
    
    # Calculate sampling rate
    mean_interval = time_diffs.mean()
    sampling_rate = 1.0 / mean_interval if mean_interval > 0 else 0
    
    return {
        'sampling_rate_hz': sampling_rate,
        'mean_interval_ms': mean_interval * 1000,
        'min_interval_ms': time_diffs.min() * 1000,
        'max_interval_ms': time_diffs.max() * 1000,
        'interval_std_ms': time_diffs.std() * 1000,
        'total_duration_minutes': (timestamps.max() - timestamps.min()) / 60
    }

def filter_by_phase(measurements_df: pd.DataFrame, phase: str) -> pd.DataFrame:
    """
    Filter measurements by session phase
    
    Args:
        measurements_df: Preprocessed measurements with 'phase' column
        phase: 'Calibration', 'Cognitive Task', 'Memory Assessment', or 'All Phases'
    """
    if phase == 'All Phases':
        return measurements_df
    
    if 'phase' not in measurements_df.columns:
        # If phase info not available, estimate based on timestamp
        from .metrics import segment_session_data
        measurements_df, _ = segment_session_data(measurements_df)
    
    return measurements_df[measurements_df['phase'] == phase]

def create_attention_funnel_data(measurements_df: pd.DataFrame, base_impressions: int = 10000) -> Dict:
    """
    Create attention funnel data for visualization
    """
    # Calculate rates from actual data
    total_measurements = len(measurements_df)
    viewable_count = len(measurements_df[measurements_df['confidence'] > 0.5])
    eyes_on_count = len(measurements_df[measurements_df['confidence'] > 0.8]) 
    
    # Calculate engagement score and high engagement periods
    engagement_score = measurements_df['confidence'] * (1 + measurements_df['diameterMM'] / measurements_df['diameterMM'].mean())
    engaged_count = len(measurements_df[engagement_score > engagement_score.quantile(0.7)])
    
    # Scale to funnel visualization
    viewable_rate = viewable_count / total_measurements
    eyes_on_rate = eyes_on_count / total_measurements
    engaged_rate = engaged_count / total_measurements
    
    funnel_data = {
        'stages': ['Impressions', 'Viewable', 'Eyes-On', 'Engaged'],
        'counts': [
            base_impressions,
            int(base_impressions * viewable_rate),
            int(base_impressions * eyes_on_rate),
            int(base_impressions * engaged_rate)
        ],
        'rates': [
            100.0,
            viewable_rate * 100,
            eyes_on_rate * 100,
            engaged_rate * 100
        ],
        'colors': ['#636EFA', '#EF553B', '#00CC96', '#AB63FA']
    }
    
    return funnel_data

def export_processed_data(data_dict: Dict, output_path: str) -> None:
    """
    Export processed data for external analysis
    """
    output_dir = Path(output_path)
    output_dir.mkdir(exist_ok=True)
    
    # Export main dataframes
    for name, df in data_dict.items():
        if isinstance(df, pd.DataFrame):
            export_file = output_dir / f"{name}_processed.csv"
            df.to_csv(export_file, index=False)
            print(f"📊 Exported {name}: {export_file}")
    
    # Export summary statistics
    if 'measurements' in data_dict:
        from .metrics import generate_summary_stats
        summary = generate_summary_stats(data_dict['measurements'])
        
        summary_file = output_dir / "session_summary.json"
        with open(summary_file, 'w') as f:
            json.dump(summary, f, indent=2, default=str)
        print(f"📈 Exported summary: {summary_file}")

def validate_data_quality(measurements_df: pd.DataFrame) -> Dict:
    """
    Validate data quality and return assessment
    """
    validation_results = {
        'total_measurements': len(measurements_df),
        'data_quality': 'Good',
        'issues': [],
        'warnings': []
    }
    
    # Check for missing values
    missing_diameter = measurements_df['diameterMM'].isna().sum()
    missing_confidence = measurements_df['confidence'].isna().sum()
    
    if missing_diameter > 0:
        validation_results['issues'].append(f"Missing diameter values: {missing_diameter}")
    
    if missing_confidence > 0:
        validation_results['issues'].append(f"Missing confidence values: {missing_confidence}")
    
    # Check confidence distribution
    low_confidence_percent = (measurements_df['confidence'] < 0.5).mean() * 100
    if low_confidence_percent > 30:
        validation_results['warnings'].append(f"High percentage of low confidence measurements: {low_confidence_percent:.1f}%")
    
    # Check diameter range
    diameter_mean = measurements_df['diameterMM'].mean()
    diameter_std = measurements_df['diameterMM'].std()
    
    if diameter_std < 0.1:
        validation_results['warnings'].append("Very low pupil diameter variability - check if tracking is working properly")
    
    if diameter_mean < 1.0 or diameter_mean > 8.0:
        validation_results['warnings'].append(f"Unusual mean diameter: {diameter_mean:.2f}mm")
    
    # Check sampling consistency
    sampling_info = calculate_sampling_rate(measurements_df)
    if sampling_info['sampling_rate_hz'] < 20:
        validation_results['warnings'].append(f"Low sampling rate: {sampling_info['sampling_rate_hz']:.1f}Hz")
    
    # Overall quality assessment
    if len(validation_results['issues']) > 0:
        validation_results['data_quality'] = 'Poor'
    elif len(validation_results['warnings']) > 2:
        validation_results['data_quality'] = 'Fair'
    
    return validation_results

# Convenience function for quick data loading
def quick_load_session(session_name: str = 'Session_7_23_2025') -> Tuple[pd.DataFrame, Dict]:
    """
    Quick loader for session data with preprocessing
    
    Returns:
        Tuple of (processed_measurements_df, all_session_data)
    """
    # Construct path relative to current location
    session_path = f"../Firebase/{session_name}"
    
    try:
        # Load all session data
        session_data = load_session_data(session_path)
        
        # Preprocess measurements
        measurements = preprocess_measurements(session_data['measurements'])
        
        # Validate data quality
        quality_report = validate_data_quality(measurements)
        print(f"📊 Data Quality: {quality_report['data_quality']}")
        
        if quality_report['warnings']:
            for warning in quality_report['warnings']:
                print(f"⚠️ {warning}")
        
        return measurements, session_data
        
    except Exception as e:
        print(f"❌ Error loading session data: {e}")
        raise