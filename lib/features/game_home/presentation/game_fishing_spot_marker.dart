import 'package:flutter/material.dart';

/// The shared fishing spot body for the GPS and panoramic maps.
class GameFishingSpotMarker extends StatelessWidget {
  const GameFishingSpotMarker({
    super.key,
    required this.name,
    required this.rarity,
    required this.isNew,
  });

  static const _beaconAsset =
      'assets/fishing/map_markers/fishing_spot_beacon_3d.png';

  final String name;
  final int rarity;
  final bool isNew;

  Color get _rarityColor {
    switch (rarity) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.purple;
      case 4:
        return Colors.orange;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get _rarityLabel {
    switch (rarity) {
      case 1:
        return 'Common';
      case 2:
        return 'Rare';
      case 3:
        return 'Epic';
      case 4:
        return 'Legendary';
      case 5:
        return 'Mythic';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rarityColor = _rarityColor;
    return Semantics(
      label: 'Fishing spot: $name, $_rarityLabel rarity${isNew ? ', new' : ''}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 118,
          height: 124,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 40,
                child: Container(
                  width: 84,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: rarityColor.withValues(alpha: 0.8),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: rarityColor.withValues(alpha: 0.34),
                        blurRadius: 20,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 58,
                child: Container(
                  width: 58,
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: RadialGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        rarityColor.withValues(alpha: 0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                child: Image.asset(
                  _beaconAsset,
                  width: 78,
                  height: 78,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              Positioned(
                top: 12,
                right: 16,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF082B36),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: rarityColor.withValues(alpha: 0.55),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.phishing,
                    color: Color(0xFF7DF9FF),
                    size: 14,
                  ),
                ),
              ),
              Positioned(
                left: 3,
                right: 3,
                bottom: 18,
                child: Align(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 112),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xE6091D24),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: rarityColor.withValues(alpha: 0.7),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              if (isNew)
                const Positioned(
                  bottom: 2,
                  child: _NewSpotBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewSpotBadge extends StatelessWidget {
  const _NewSpotBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          'NEW',
          style: TextStyle(color: Colors.white, fontSize: 8),
        ),
      ),
    );
  }
}
