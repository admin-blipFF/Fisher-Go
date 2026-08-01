package com.fishergo.app

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import org.maplibre.android.MapLibre
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.renderer.MapRenderer
import org.maplibre.android.style.layers.FillLayer
import org.maplibre.android.style.layers.PropertyFactory

/**
 * Isolates MapLibre Native raster work from Flutter platform-view composition.
 * This activity is included only in profile builds used by the API 35 gate.
 */
class NativeMapProofActivity : Activity() {
    private lateinit var mapView: MapView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MapLibre.getInstance(this)

        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.rgb(207, 231, 213))
        }
        mapView = MapView(this)
        root.addView(
            mapView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )

        val proofLabel = TextView(this).apply {
            text = "Native MapLibre surface proof"
            contentDescription = "Native MapLibre surface proof"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.argb(185, 15, 54, 62))
            setPadding(20, 12, 20, 12)
        }
        root.addView(
            proofLabel,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.START,
            ).apply {
                topMargin = 32
                leftMargin = 24
            },
        )

        setContentView(root)
        mapView.onCreate(savedInstanceState)
        mapView.getMapAsync { map ->
            map.cameraPosition = CameraPosition.Builder()
                .target(LatLng(22.3819, 114.1874))
                .zoom(16.0)
                .tilt(45.0)
                .bearing(0.0)
                .build()
            if (intent.getBooleanExtra("noTilePrefetch", false)) {
                map.prefetchesTiles = false
                map.prefetchZoomDelta = 0
            }
            if (intent.getBooleanExtra("whenDirtyRefresh", false)) {
                mapView.renderingRefreshMode = MapRenderer.RenderingRefreshMode.WHEN_DIRTY
            }
            map.setStyle("asset://fishergo_game_style.json") { style ->
                if (intent.getBooleanExtra("noBuildingExtrusion", false)) {
                    style.removeLayer("building-3d")
                }
                if (intent.getBooleanExtra("noLandcover", false)) {
                    style.removeLayer("grass")
                    style.removeLayer("wood")
                    style.removeLayer("park")
                }
                if (intent.getBooleanExtra("noFillAntialias", false)) {
                    listOf("grass", "wood", "park", "water").forEach { layerId ->
                        style.getLayerAs<FillLayer>(layerId)?.setProperties(
                            PropertyFactory.fillAntialias(false),
                        )
                    }
                }
                if (intent.getBooleanExtra("noRoads", false)) {
                    style.removeLayer("road-main")
                }
                if (intent.getBooleanExtra("noWater", false)) {
                    style.removeLayer("water")
                }
                if (intent.getBooleanExtra("noWaterOutline", false)) {
                    style.getLayerAs<FillLayer>("water")?.setProperties(
                        PropertyFactory.fillOutlineColor(Color.TRANSPARENT),
                    )
                }
                if (intent.getBooleanExtra("noWaterway", false)) {
                    style.removeLayer("waterway")
                }
                if (intent.getBooleanExtra("noPier", false)) {
                    style.removeLayer("pier")
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        mapView.onStart()
    }

    override fun onResume() {
        super.onResume()
        mapView.onResume()
    }

    override fun onPause() {
        mapView.onPause()
        super.onPause()
    }

    override fun onStop() {
        mapView.onStop()
        super.onStop()
    }

    override fun onLowMemory() {
        super.onLowMemory()
        mapView.onLowMemory()
    }

    override fun onDestroy() {
        mapView.onDestroy()
        super.onDestroy()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        mapView.onSaveInstanceState(outState)
        super.onSaveInstanceState(outState)
    }
}
