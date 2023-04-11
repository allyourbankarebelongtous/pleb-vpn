from webui import create_app

app = create_app()

if __name__ == '__main__':
    app.run(host = "0.0.0.0", port = 2420, debug=True)

else:
    gunicorn_app = create_app()