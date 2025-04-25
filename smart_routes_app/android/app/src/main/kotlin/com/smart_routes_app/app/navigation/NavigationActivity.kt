package com.smartroutes.app.navigation

import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.material.floatingactionbutton.FloatingActionButton
import com.google.android.libraries.navigation.*
import com.smartroutes.app.R
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

class NavigationActivity : AppCompatActivity() {

    private lateinit var navigator: Navigator
    private lateinit var navigationFragment: SupportNavigationFragment
    private lateinit var routingOptions: RoutingOptions

    private var locationPermissionGranted = false
    private val LOCATION_PERMISSION_REQUEST_CODE = 1001

    companion object {
        private const val CHANNEL = "com.smartroutes.navigation"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_navigation)

        findViewById<FloatingActionButton>(R.id.fab_back).setOnClickListener {
            navigator.stopGuidance()
            finishWithResult()
        }

        requestLocationPermissionAndInitSdk()
    }

    private fun requestLocationPermissionAndInitSdk() {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION)
            == PackageManager.PERMISSION_GRANTED
        ) {
            locationPermissionGranted = true
            initializeNavigationSdk()
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(android.Manifest.permission.ACCESS_FINE_LOCATION),
                LOCATION_PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun initializeNavigationSdk() {
        if (!locationPermissionGranted) {
            toast("Permissão de localização não concedida.")
            return
        }

        NavigationApi.getNavigator(this, object : NavigationApi.NavigatorListener {
            override fun onNavigatorReady(nav: Navigator) {
                if (::navigator.isInitialized) {
                    navigator.stopGuidance()
                    navigator.clearDestinations()
                }
                navigator = nav
                toast("Navegador pronto.")

                val fragment = supportFragmentManager.findFragmentById(R.id.navigation_fragment)
                if (fragment is SupportNavigationFragment) {
                    navigationFragment = fragment
                } else {
                    toast("Fragmento de navegação não encontrado.")
                    return
                }

                routingOptions = RoutingOptions().apply {
                    val travelMode = RoutingOptions.TravelMode.DRIVING
                }

                navigationFragment.getMapAsync { map ->
                    map.followMyLocation(1)
                }

                handleIncomingStops()
            }

            override fun onError(errorCode: Int) {
                val message = when (errorCode) {
                    NavigationApi.ErrorCode.NOT_AUTHORIZED -> "Chave da API inválida ou não autorizada."
                    NavigationApi.ErrorCode.TERMS_NOT_ACCEPTED -> "Termos de uso não aceitos."
                    NavigationApi.ErrorCode.NETWORK_ERROR -> "Erro de rede."
                    NavigationApi.ErrorCode.LOCATION_PERMISSION_MISSING -> "Permissão de localização ausente."
                    else -> "Erro desconhecido: $errorCode"
                }
                toast(message)
                Log.e("NavigationActivity", message)
            }
        })
    }

    private fun handleIncomingStops() {
        val stops = intent.getSerializableExtra("stops") as? ArrayList<HashMap<String, Double>>
        if (stops.isNullOrEmpty()) {
            toast("Nenhuma parada recebida.")
            finish()
            return
        }

        val waypoints = stops.map {
            val lat = it["latitude"] ?: 0.0
            val lng = it["longitude"] ?: 0.0
            Waypoint.builder()
                .setLatLng(lat, lng)
                .build()
        }

        navigator.clearDestinations()
        navigator.stopGuidance()

        window.decorView.postDelayed({
            val future = navigator.setDestinations(waypoints, routingOptions)

            future.setOnResultListener { status ->
                when (status) {
                    Navigator.RouteStatus.OK -> {
                        navigator.setAudioGuidance(Navigator.AudioGuidance.VOICE_ALERTS_AND_GUIDANCE)
                        navigator.startGuidance()
                    }
                    Navigator.RouteStatus.NO_ROUTE_FOUND -> toast("Nenhuma rota encontrada.")
                    Navigator.RouteStatus.NETWORK_ERROR -> toast("Erro de rede ao buscar rota.")
                    Navigator.RouteStatus.ROUTE_CANCELED -> toast("Rota cancelada.")
                    else -> toast("Erro ao iniciar navegação: $status")
                }
            }
        }, 800) // Delay aumentado para 800ms
    }

    private fun toast(msg: String) {
        Toast.makeText(this, msg, Toast.LENGTH_LONG).show()
    }

    private fun finishWithResult() {
        val intent = Intent("com.smartroutes.navigationEnded")
        sendBroadcast(intent)
        finish()
    }

    override fun onStop() {
        super.onStop()
        finishWithResult()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == LOCATION_PERMISSION_REQUEST_CODE && grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            locationPermissionGranted = true
            initializeNavigationSdk()
        } else {
            toast("Permissão de localização negada.")
        }
    }
}
