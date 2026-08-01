package co.za.sanlam.sanlam_chronic

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
    // Android 15+ (targetSdk 35) enables edge-to-edge by default; opt in
    // explicitly so insets are handled consistently on all supported versions.
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
