from webui import create_app

app = create_app()

if __name__ == '__main__':
    app.run(debug=True)

else:
    gunicorn_app = create_app()