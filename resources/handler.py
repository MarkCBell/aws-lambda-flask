"""
This module converts an AWS API Gateway proxied request to a WSGI request.

Inspired by:
 - https://github.com/miserlou/zappa
 - https://github.com/logandk/serverless-wsgi
"""
import base64
import importlib
import io
import os
import sys

from werkzeug.datastructures import Headers
from werkzeug.wrappers import Response
from werkzeug.urls import url_encode, url_unquote

# List of MIME types that should not be base64 encoded.
# MIME types within `text/*` are included by default.
TEXT_MIME_TYPES = {
    "application/json",
    "application/javascript",
    "application/xml",
    "application/vnd.api+json",
    "image/svg+xml",
}

APP_NAME = os.environ['app_name']
APP_FILE = os.environ['app_file']

def split_headers(headers):
    """
    If there are multiple occurrences of headers then create variations in order to pass them through APIGW.
    This is a hack that's currently needed.
    See encode_response in: https://github.com/Miserlou/Zappa/blob/master/zappa/middleware.py
    """
    return {key + (str(index) if index else ""): value for key in headers.keys() for index, value in enumerate(headers.get_all(key))}


def group_headers(headers):
    return {key: headers.get_all(key) for key in headers.keys()}


def encode_query_string(event):
    params = event.get("multiValueQueryStringParameters")
    if not params:
        params = event.get("queryStringParameters")
    if not params:
        params = event.get("query")
    if not params:
        params = ""
    return url_encode(params)


def get_script_name(headers, request_context):
    return f"/{request_context.get('stage', '')}" if "amazonaws.com" in headers.get("Host", "") else ""


def get_body_bytes(event):
    body = event["body"] or ""
    if event.get("isBase64Encoded", False):
        body = base64.b64decode(body)

    if isinstance(body, str):
        body = body.encode("utf-8")

    return body


def setup_environ_items(environ, headers):
    for key, value in environ.items():
        if isinstance(value, str):
            environ[key] = value.encode("utf-8").decode("latin1", "replace")

    for key, value in headers.items():
        key = f"HTTP_{key.upper()}".replace("-", "_")
        if key not in ("HTTP_CONTENT_TYPE", "HTTP_CONTENT_LENGTH"):
            environ[key] = value

    return environ


def generate_response(response, event):
    returndict = {"statusCode": response.status_code}

    if "multiValueHeaders" in event:
        returndict["multiValueHeaders"] = group_headers(response.headers)
    else:
        returndict["headers"] = split_headers(response.headers)

    if response.data:
        mimetype = response.mimetype or "text/plain"
        if (mimetype.startswith("text/") or mimetype in TEXT_MIME_TYPES) and not response.headers.get("Content-Encoding", ""):
            returndict["body"] = response.get_data(as_text=True)
            returndict["isBase64Encoded"] = False
        else:
            returndict["body"] = base64.b64encode(response.data).decode("utf-8")
            returndict["isBase64Encoded"] = True

    return returndict


def handler(event, context):
    # from APP_FILE import APP_NAME as app
    module = importlib.import_module(APP_FILE)
    app = getattr(module, APP_NAME)

    if event.get("source") in ["aws.events", "serverless-plugin-warmup"]:
        print("Lambda warming event received, skipping handler")
        return {}

    headers = Headers(event["multiValueHeaders"] if "multiValueHeaders" in event else event["headers"])

    script_name = get_script_name(headers, event.get("requestContext", {}))

    # If a user is using a custom domain on API Gateway, they may have a base path in their URL.
    # This allows us to strip it out via an optional environment variable.
    path_info = event["path"]
    base_path = os.environ.get("API_GATEWAY_BASE_PATH")
    if base_path:
        script_name = f"/{base_path}"

        if path_info.startswith(script_name):
            path_info = path_info[len(script_name) :]

    body = get_body_bytes(event)

    environ = {
        "CONTENT_LENGTH": str(len(body)),
        "CONTENT_TYPE": headers.get("Content-Type", ""),
        "PATH_INFO": url_unquote(path_info),
        "QUERY_STRING": encode_query_string(event),
        "REMOTE_ADDR": event.get("requestContext", {}).get("identity", {}).get("sourceIp", ""),
        "REMOTE_USER": event.get("requestContext", {}).get("authorizer", {}).get("principalId", ""),
        "REQUEST_METHOD": event.get("httpMethod", {}),
        "SCRIPT_NAME": script_name,
        "SERVER_NAME": headers.get("Host", "lambda"),
        "SERVER_PORT": headers.get("X-Forwarded-Port", "80"),
        "SERVER_PROTOCOL": "HTTP/1.1",
        "wsgi.errors": sys.stderr,
        "wsgi.input": io.BytesIO(body),
        "wsgi.multiprocess": False,
        "wsgi.multithread": False,
        "wsgi.run_once": False,
        "wsgi.url_scheme": headers.get("X-Forwarded-Proto", "http"),
        "wsgi.version": (1, 0),
        "serverless.authorizer": event.get("requestContext", {}).get("authorizer"),
        "serverless.event": event,
        "serverless.context": context,
    }

    environ = setup_environ_items(environ, headers)

    response = Response.from_app(app, environ)
    return generate_response(response, event)
