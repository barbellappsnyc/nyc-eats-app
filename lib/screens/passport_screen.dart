import 'package:flutter/material.dart';

class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  @override
  Widget build(BuildContext context) {
    // 🔧 TWEAK: Changed from 1.45 to 1.35 to give you more vertical space (less "stubby")
    const double bookAspectRatio = 1.35;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: bookAspectRatio,
          child: Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
              // 📖 LEATHER COVER
              image: DecorationImage(
                image: AssetImage('assets/images/leather_cover.jpg'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.2),
                  BlendMode.darken,
                ),
              ),
            ),
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                // 📄 LEFT PAGE (Visa)
                Expanded(child: _buildRealisticPage(isLeft: true)),

                // 📚 SPINE
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF0D0D0D),
                        Color(0xFF202020),
                        Color(0xFF0D0D0D),
                      ],
                    ),
                  ),
                ),

                // 📄 RIGHT PAGE (Stamps)
                Expanded(child: _buildRealisticPage(isLeft: false)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRealisticPage({required bool isLeft}) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFFDFBF7),
        borderRadius: isLeft
            ? BorderRadius.only(
                topLeft: Radius.circular(4),
                bottomLeft: Radius.circular(4),
              )
            : BorderRadius.only(
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
        image: DecorationImage(
          image: AssetImage('assets/images/passport_paper.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          // 1. CONTENT LAYER (Safe Layout)
          LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 12.0,
                ),
                child: isLeft
                    ? _buildVisaContent(constraints)
                    : _buildStampsContent(),
              );
            },
          ),

          // 2. SHADOW LAYER (Curvature)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
                  end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.transparent,
                    Colors.black.withOpacity(0.05),
                  ],
                  stops: [0.0, 0.15, 1.0],
                ),
              ),
            ),
          ),

          // 3. NOISE LAYER (Texture)
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: Container(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // --- 🛂 LEFT PAGE: THE VISA (Robust + Styled) ---
  Widget _buildVisaContent(BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✨ GOLD FOIL HEADER (Slightly darker gold for contrast)
        Center(
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Color(0xFF8B6F3A),
                Color(0xFFF2D57E),
                Color(0xFFB88A44),
              ], // Darker start
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Column(
              children: [
                Text(
                  "NYC EXPLORER",
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.w900,
                    fontSize:
                        constraints.maxWidth * 0.1, // Responsive Text Size
                    color: Colors.white,
                    letterSpacing: 3.0,
                  ),
                ),
                SizedBox(height: 4),
                Divider(color: Colors.white, thickness: 1, height: 2),
                Divider(color: Colors.white, thickness: 0.5, height: 4),
              ],
            ),
          ),
        ),

        Spacer(flex: 1),

        // 🖋️ INK BLEED DATA
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.85),
            BlendMode.srcATop,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Box (Responsive Size)
              Container(
                width: constraints.maxWidth * 0.38, // 38% of page width
                height: constraints.maxHeight * 0.45, // 45% of page height
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  color: Colors.grey[100],
                ),
                child: Center(
                  child: Icon(Icons.person, color: Colors.grey[300], size: 40),
                ),
              ),
              SizedBox(width: 8),

              // Text Fields
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  mainAxisSize: MainAxisSize.max, // Fill the height of the row
                  children: [
                    _buildField("SURNAME", "VIBE CODER"),
                    SizedBox(height: 4),
                    _buildField("GIVEN NAME", "FOUNDER"),
                    SizedBox(height: 4),
                    _buildField("NATIONALITY", "NEW YORKER"),
                  ],
                ),
              ),
            ],
          ),
        ),

        Spacer(flex: 2),

        // 🤖 MACHINE READABLE ZONE
        Opacity(
          opacity: 0.7,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            child: Text(
              "P<USAEXPLORER<<VIBE<CODER<<<<<<<<<<<<<<<<\n8904326M2301175USA<<<<<<<<<<<<<<<<<<<<<<<4",
              style: TextStyle(
                fontFamily: 'Courier',
                fontWeight: FontWeight.w700,
                color: Color(0xFF2A2A2A),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStampsContent() {
    return Stack(
      children: [
        Center(
          child: Opacity(
            opacity: 0.08,
            child: Icon(Icons.local_pizza, size: 100, color: Colors.brown),
          ),
        ),
        // Example Stamp
        Positioned(
          top: 40,
          left: 10,
          child: Transform.rotate(
            angle: -0.2,
            child: Opacity(
              opacity: 0.85, // Ink bleed effect
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red[900]!, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    Text(
                      "CARBONE",
                      style: TextStyle(
                        color: Colors.red[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      "17 JAN 2026",
                      style: TextStyle(color: Colors.red[900], fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: Colors.black45,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11, // Slightly smaller to be safe
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F1F1F),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
