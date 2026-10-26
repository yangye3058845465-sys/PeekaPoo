package com.insideout.peekapoo;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

// Thin shell around the PeekaPoo web app bundled in assets/www.
// The page talks to the PeekaPoo hub over the local network (address is set on the login screen).
public class MainActivity extends Activity {
    private WebView web;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(Color.parseColor("#120d2b"));
        getWindow().setNavigationBarColor(Color.parseColor("#0d0921"));

        web = new WebView(this);
        web.setBackgroundColor(Color.parseColor("#120d2b"));
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccess(true);
        s.setAllowFileAccessFromFileURLs(true);
        s.setAllowUniversalAccessFromFileURLs(true);
        web.setWebViewClient(new WebViewClient());
        setContentView(web);

        if (savedInstanceState != null) {
            web.restoreState(savedInstanceState);
        } else {
            web.loadUrl("file:///android_asset/www/index.html");
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        web.saveState(outState);
    }

    @Override
    public void onBackPressed() {
        // close an open overlay (chat / Bristol sheet) first, otherwise leave the app
        web.evaluateJavascript(
            "(function(){var c=document.getElementById('chat'),s=document.getElementById('sheet');"
            + "if(s&&!s.hidden){s.hidden=true;return 1}if(c&&!c.hidden){c.hidden=true;return 1}return 0})()",
            handled -> {
                if (!"1".equals(handled)) {
                    finish();
                }
            });
    }
}
