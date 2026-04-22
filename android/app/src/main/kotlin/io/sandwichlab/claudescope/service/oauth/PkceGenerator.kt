package io.sandwichlab.claudescope.service.oauth

import android.util.Base64
import java.security.MessageDigest
import java.security.SecureRandom

object PkceGenerator {

    private const val VERIFIER_BYTES = 32
    private const val BASE64_FLAGS = Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP

    private val random = SecureRandom()

    fun generateVerifier(): String {
        val bytes = ByteArray(VERIFIER_BYTES)
        random.nextBytes(bytes)
        return Base64.encodeToString(bytes, BASE64_FLAGS)
    }

    fun challengeFor(verifier: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(Charsets.US_ASCII))
        return Base64.encodeToString(digest, BASE64_FLAGS)
    }

    fun generateState(): String = generateVerifier()
}
