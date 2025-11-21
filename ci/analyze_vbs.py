#!/usr/bin/env python3
"""
Zephyr ECU Prototype - VBS Data Analysis Tool
==============================================
Purpose: Analyze experimental VBS data and generate reports
Usage: python3 analyze_vbs.py --input file.vbs --output report.csv
"""

import argparse
import csv
import logging
import sys
from pathlib import Path
from typing import Dict, List, Tuple
from collections import defaultdict
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class VBSAnalyzer:
    """Analyze VBS data from ECU experiments"""
    
    def __init__(self, input_file: Path):
        self.input_file = input_file
        self.messages: List[Dict] = []
        self.statistics: Dict = {}
        
    def load_vbs_file(self) -> bool:
        """Load and parse VBS file"""
        logger.info(f"Loading VBS file: {self.input_file}")
        
        try:
            with open(self.input_file, 'r') as f:
                lines = f.readlines()
            
            # Find data section
            data_section = False
            for line in lines:
                line = line.strip()
                
                if line == '[Data]':
                    data_section = True
                    continue
                
                if data_section and line and not line.startswith(';'):
                    # Parse: timestamp,id,dlc,data
                    parts = line.split(',')
                    if len(parts) >= 4:
                        try:
                            msg = {
                                'timestamp': float(parts[0]),
                                'id': int(parts[1], 16),
                                'dlc': int(parts[2]),
                                'data': parts[3] if len(parts) > 3 else ''
                            }
                            self.messages.append(msg)
                        except ValueError as e:
                            logger.warning(f"Skipping malformed line: {line} ({e})")
            
            logger.info(f"Loaded {len(self.messages)} messages")
            return len(self.messages) > 0
            
        except FileNotFoundError:
            logger.error(f"File not found: {self.input_file}")
            return False
        except Exception as e:
            logger.error(f"Error loading VBS file: {e}")
            return False
    
    def analyze_timing(self) -> Dict:
        """Analyze message timing characteristics"""
        logger.info("Analyzing message timing...")
        
        if not self.messages:
            return {}
        
        # Sort by timestamp
        sorted_msgs = sorted(self.messages, key=lambda x: x['timestamp'])
        
        # Calculate inter-message delays per ID
        delays_by_id = defaultdict(list)
        last_timestamp_by_id = {}
        
        for msg in sorted_msgs:
            msg_id = msg['id']
            timestamp = msg['timestamp']
            
            if msg_id in last_timestamp_by_id:
                delay = timestamp - last_timestamp_by_id[msg_id]
                delays_by_id[msg_id].append(delay)
            
            last_timestamp_by_id[msg_id] = timestamp
        
        # Calculate statistics
        timing_stats = {}
        for msg_id, delays in delays_by_id.items():
            if delays:
                timing_stats[msg_id] = {
                    'count': len(delays) + 1,
                    'min_delay': min(delays),
                    'max_delay': max(delays),
                    'avg_delay': sum(delays) / len(delays),
                    'frequency': 1.0 / (sum(delays) / len(delays)) if delays else 0
                }
        
        return timing_stats
    
    def analyze_message_distribution(self) -> Dict:
        """Analyze message ID distribution"""
        logger.info("Analyzing message distribution...")
        
        id_counts = defaultdict(int)
        for msg in self.messages:
            id_counts[msg['id']] += 1
        
        total = len(self.messages)
        distribution = {
            msg_id: {
                'count': count,
                'percentage': (count / total) * 100
            }
            for msg_id, count in id_counts.items()
        }
        
        return distribution
    
    def detect_anomalies(self) -> List[Dict]:
        """Detect timing anomalies and irregularities"""
        logger.info("Detecting anomalies...")
        
        anomalies = []
        timing_stats = self.analyze_timing()
        
        for msg_id, stats in timing_stats.items():
            # Check for excessive jitter
            jitter = stats['max_delay'] - stats['min_delay']
            if jitter > stats['avg_delay'] * 0.5:  # >50% jitter
                anomalies.append({
                    'type': 'HIGH_JITTER',
                    'msg_id': f"0x{msg_id:03X}",
                    'value': jitter,
                    'severity': 'MEDIUM'
                })
            
            # Check for irregular frequency
            expected_freq = stats['frequency']
            if expected_freq < 1.0 or expected_freq > 100.0:
                anomalies.append({
                    'type': 'IRREGULAR_FREQUENCY',
                    'msg_id': f"0x{msg_id:03X}",
                    'value': expected_freq,
                    'severity': 'LOW'
                })
        
        return anomalies
    
    def generate_summary_statistics(self) -> Dict:
        """Generate overall summary statistics"""
        logger.info("Generating summary statistics...")
        
        if not self.messages:
            return {}
        
        timestamps = [msg['timestamp'] for msg in self.messages]
        duration = max(timestamps) - min(timestamps)
        
        summary = {
            'total_messages': len(self.messages),
            'unique_ids': len(set(msg['id'] for msg in self.messages)),
            'duration': duration,
            'avg_rate': len(self.messages) / duration if duration > 0 else 0,
            'start_time': min(timestamps),
            'end_time': max(timestamps)
        }
        
        return summary
    
    def export_to_csv(self, output_file: Path) -> bool:
        """Export analysis results to CSV"""
        logger.info(f"Exporting results to: {output_file}")
        
        try:
            with open(output_file, 'w', newline='') as f:
                writer = csv.writer(f)
                
                # Write header
                writer.writerow(['Category', 'Metric', 'Value', 'Unit'])
                
                # Summary statistics
                summary = self.generate_summary_statistics()
                writer.writerow(['Summary', 'Total Messages', 
                               summary.get('total_messages', 0), 'count'])
                writer.writerow(['Summary', 'Unique IDs', 
                               summary.get('unique_ids', 0), 'count'])
                writer.writerow(['Summary', 'Duration', 
                               f"{summary.get('duration', 0):.2f}", 's'])
                writer.writerow(['Summary', 'Average Rate', 
                               f"{summary.get('avg_rate', 0):.2f}", 'msg/s'])
                
                writer.writerow([])  # Empty row
                
                # Timing statistics
                writer.writerow(['Message ID', 'Count', 'Avg Delay (ms)', 
                               'Frequency (Hz)', 'Min Delay', 'Max Delay'])
                
                timing_stats = self.analyze_timing()
                for msg_id, stats in sorted(timing_stats.items()):
                    writer.writerow([
                        f"0x{msg_id:03X}",
                        stats['count'],
                        f"{stats['avg_delay']*1000:.2f}",
                        f"{stats['frequency']:.2f}",
                        f"{stats['min_delay']*1000:.2f}",
                        f"{stats['max_delay']*1000:.2f}"
                    ])
                
                writer.writerow([])  # Empty row
                
                # Anomalies
                writer.writerow(['Anomaly Type', 'Message ID', 'Value', 'Severity'])
                anomalies = self.detect_anomalies()
                for anomaly in anomalies:
                    writer.writerow([
                        anomaly['type'],
                        anomaly['msg_id'],
                        f"{anomaly['value']:.4f}",
                        anomaly['severity']
                    ])
            
            logger.info(f"✅ CSV export complete: {output_file}")
            return True
            
        except Exception as e:
            logger.error(f"Error exporting CSV: {e}")
            return False
    
    def generate_report(self) -> str:
        """Generate human-readable text report"""
        logger.info("Generating text report...")
        
        summary = self.generate_summary_statistics()
        timing = self.analyze_timing()
        distribution = self.analyze_message_distribution()
        anomalies = self.detect_anomalies()
        
        report = []
        report.append("=" * 80)
        report.append("Zephyr ECU Experimental Data Analysis Report")
        report.append("=" * 80)
        report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append(f"Input File: {self.input_file}")
        report.append("")
        
        # Summary
        report.append("SUMMARY STATISTICS")
        report.append("-" * 80)
        report.append(f"  Total Messages:     {summary.get('total_messages', 0)}")
        report.append(f"  Unique Message IDs: {summary.get('unique_ids', 0)}")
        report.append(f"  Duration:           {summary.get('duration', 0):.2f}s")
        report.append(f"  Average Rate:       {summary.get('avg_rate', 0):.2f} msg/s")
        report.append("")
        
        # Top message IDs
        report.append("TOP MESSAGE IDs (by count)")
        report.append("-" * 80)
        sorted_dist = sorted(distribution.items(), 
                           key=lambda x: x[1]['count'], 
                           reverse=True)[:10]
        for msg_id, stats in sorted_dist:
            report.append(f"  0x{msg_id:03X}: {stats['count']:5d} messages "
                        f"({stats['percentage']:.1f}%)")
        report.append("")
        
        # Timing analysis
        report.append("TIMING ANALYSIS (Top 10 by frequency)")
        report.append("-" * 80)
        sorted_timing = sorted(timing.items(), 
                             key=lambda x: x[1]['frequency'], 
                             reverse=True)[:10]
        report.append(f"{'ID':<8} {'Count':<8} {'Freq (Hz)':<12} {'Avg Delay (ms)':<16}")
        report.append("-" * 80)
        for msg_id, stats in sorted_timing:
            report.append(f"0x{msg_id:03X}   {stats['count']:<8} "
                        f"{stats['frequency']:<12.2f} "
                        f"{stats['avg_delay']*1000:<16.2f}")
        report.append("")
        
        # Anomalies
        if anomalies:
            report.append("DETECTED ANOMALIES")
            report.append("-" * 80)
            for anomaly in anomalies:
                report.append(f"  [{anomaly['severity']}] {anomaly['type']}: "
                            f"{anomaly['msg_id']} = {anomaly['value']:.4f}")
        else:
            report.append("No anomalies detected")
        
        report.append("")
        report.append("=" * 80)
        
        return "\n".join(report)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Analyze VBS experimental data from Zephyr ECU'
    )
    parser.add_argument(
        '--input', '-i',
        type=Path,
        required=True,
        help='Input VBS file path'
    )
    parser.add_argument(
        '--output', '-o',
        type=Path,
        help='Output CSV file path (default: analysis.csv)'
    )
    parser.add_argument(
        '--report', '-r',
        type=Path,
        help='Output text report file path'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose logging'
    )
    
    args = parser.parse_args()
    
    # Configure logging level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Set default output paths
    if not args.output:
        args.output = args.input.parent / 'analysis.csv'
    
    if not args.report:
        args.report = args.input.parent / 'analysis_report.txt'
    
    # Validate input file
    if not args.input.exists():
        logger.error(f"Input file not found: {args.input}")
        sys.exit(1)
    
    # Create analyzer
    analyzer = VBSAnalyzer(args.input)
    
    # Load data
    if not analyzer.load_vbs_file():
        logger.error("Failed to load VBS file")
        sys.exit(1)
    
    # Export CSV
    if not analyzer.export_to_csv(args.output):
        logger.error("Failed to export CSV")
        sys.exit(1)
    
    # Generate text report
    report = analyzer.generate_report()
    print(report)
    
    # Save report to file
    try:
        with open(args.report, 'w') as f:
            f.write(report)
        logger.info(f"✅ Report saved: {args.report}")
    except Exception as e:
        logger.error(f"Failed to save report: {e}")
    
    logger.info("✅ Analysis complete")


if __name__ == '__main__':
    main()
