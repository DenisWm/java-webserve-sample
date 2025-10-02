package com.sample.jaxrsminimal;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/jaxrs-minimal")
public class JaxrsResource {

    @GET
    @Produces(MediaType.TEXT_HTML)
    public String helloHtml() {
        return """
    <!doctype html>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Hello • JAX-RS</title>
    <style>
      body{margin:0;min-height:100vh;display:grid;place-items:center;background:linear-gradient(135deg,#0f172a,#1e293b);color:#e2e8f0;font:16px/1.5 system-ui,-apple-system,Segoe UI,Roboto}
      .card{max-width:720px;margin:24px;padding:26px 28px;background:rgba(15,23,42,.55);border:1px solid rgba(148,163,184,.18);border-radius:18px;box-shadow:0 10px 30px rgba(0,0,0,.35)}
      h1{margin:0 0 8px;background:linear-gradient(90deg,#22d3ee,#a78bfa);-webkit-background-clip:text;background-clip:text;color:transparent;font-size:clamp(22px,4vw,34px)}
      .muted{color:#94a3b8}
      .mono{font-family:ui-monospace,Menlo,Consolas,monospace}
      .btn{display:inline-block;margin-top:14px;padding:10px 14px;border-radius:10px;border:1px solid rgba(148,163,184,.25);text-decoration:none;color:#e2e8f0;background:rgba(148,163,184,.10)}
      .btn:hover{background:rgba(148,163,184,.18)}
      .pill{display:inline-block;margin-right:8px;margin-top:8px;padding:6px 10px;border-radius:999px;background:rgba(148,163,184,.10);border:1px solid rgba(148,163,184,.18)}
    </style>
    <div class="card">
      <h1>Olá, JAX-RS (Jersey)!</h1>
      <p class="muted">Este endpoint retorna HTML diretamente via <span class="mono">@Produces(text/html)</span>.</p>
      <p>
        <span class="pill mono">Tomcat 10.1</span>
        <span class="pill mono">Java 24</span>
        <span class="pill mono">JAX-RS 3.1</span>
      </p>
    </div>
    """;
    }
}
