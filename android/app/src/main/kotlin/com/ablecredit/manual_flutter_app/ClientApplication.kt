package com.ablecredit.manual_flutter_app

import android.app.Application
import com.ablecredit.sdk.manager.AbleCredit

class ClientApplication: Application() {

    override fun onCreate() {
        super.onCreate()
        AbleCredit.initialize(applicationContext)
    }

}