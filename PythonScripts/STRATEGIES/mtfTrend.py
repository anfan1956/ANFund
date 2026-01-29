"""
MTF Trend Strategy - новая реализация на ANFramework
"""

import sys
from ANFramework import StrategyBase


class MTFTrendStrategy(StrategyBase):
    """Multi-Timeframe Trend Following Strategy"""

    def __init__(self, configuration_id: int):
        print(f"[MTF Trend] Initializing strategy for config_id: {configuration_id}")

        # timeframe_id=1 временно, будет обновлён в родительском классе
        super().__init__(configuration_id, timeframe_id=1, timer_interval=0.5)

        print(f"[MTF Trend] Strategy {configuration_id} ready")


def main():
    import argparse
    parser = argparse.ArgumentParser(description='MTF Trend Strategy')
    parser.add_argument('--configID', type=int, required=True, dest='config_id',
                        help='Configuration ID from database')
    args = parser.parse_args()

    try:
        strategy = MTFTrendStrategy(args.config_id)
        print("Strategy created successfully")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()