package com.mosharof.garipath.location

import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Wraps a [MethodChannel.Result] so it can be answered only once.
 *
 * A Result answered twice crashes the app ("Reply already submitted"). That is
 * easy to cause when a timeout and a location callback race each other, so
 * every async call goes through this wrapper and later replies are ignored.
 */
class OnceResult(private val result: MethodChannel.Result) : MethodChannel.Result {
    private val replied = AtomicBoolean(false)

    override fun success(value: Any?) {
        if (replied.compareAndSet(false, true)) result.success(value)
    }

    override fun error(code: String, message: String?, details: Any?) {
        if (replied.compareAndSet(false, true)) result.error(code, message, details)
    }

    override fun notImplemented() {
        if (replied.compareAndSet(false, true)) result.notImplemented()
    }
}
