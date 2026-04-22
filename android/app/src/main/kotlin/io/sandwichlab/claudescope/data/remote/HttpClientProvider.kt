package io.sandwichlab.claudescope.data.remote

import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

object HttpClientProvider {
    fun create(): OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()
}
