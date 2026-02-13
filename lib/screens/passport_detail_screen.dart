import 'package:flutter/material.dart';

class PassportDetailScreen extends StatefulWidget {
  final String heroTag; // 👈 CHANGED: We now accept the exact tag string
  final Widget cardWidget;
  final Color backgroundColor;

  const PassportDetailScreen({
    super.key,
    required this.heroTag,
    required this.cardWidget,
    required this.backgroundColor,
  });

  @override
  State<PassportDetailScreen> createState() => _PassportDetailScreenState();
}

class _PassportDetailScreenState extends State<PassportDetailScreen> {
  Offset _cardPosition = Offset.zero;
  double _cardScale = 0.85;
  double _cardRotation = 0.0;

  Offset _baseCardPosition = Offset.zero;
  double _baseScale = 0.85;
  double _baseRotation = 0.0;
  Offset _startFocalPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _cardPosition = Offset(MediaQuery.of(context).size.width / 2,
            MediaQuery.of(context).size.height / 2);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 👈 RESTORE SOLID BACKGROUND
      backgroundColor: widget.backgroundColor, 
      // backgroundColor: widget.backgroundColor.withOpacity(0.0), // OLD HACK REMOVED
      
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Changed back to black since background is light again
        leading: const CloseButton(color: Colors.black), 
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: _cardPosition.dx - 170, 
            top: _cardPosition.dy - 270,  
            child: GestureDetector(
              onScaleStart: (details) {
                _baseCardPosition = _cardPosition;
                _startFocalPoint = details.focalPoint;
                _baseScale = _cardScale;
                _baseRotation = _cardRotation;
              },
              onScaleUpdate: (details) {
                setState(() {
                  final Offset delta = details.focalPoint - _startFocalPoint;
                  _cardPosition = _baseCardPosition + delta;
                  _cardScale = (_baseScale * details.scale).clamp(0.4, 2.0);
                  _cardRotation = _baseRotation + details.rotation;
                });
              },
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scale(_cardScale)
                  ..rotateZ(_cardRotation),
                child: Hero(
                  tag: widget.heroTag, // 👈 USE THE PASSED TAG
                  child: widget.cardWidget,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Pinch to resize · Twist to rotate",
                style: TextStyle(
                    // Changed back to grey
                    color: Colors.grey[400], fontStyle: FontStyle.italic),
              ),
            ),
          )
        ],
      ),
    );
  }
}