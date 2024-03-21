import json

start_all()

server.wait_for_unit("receptdatabasen")
server.wait_for_open_port(8080)

expected = {"me": {"email": "alice@email.com", "user_name": "alice", "id": 1}}

# log in
actual = json.loads(
    client.wait_until_succeeds(
        """
        curl -v --fail -c cookie.txt -H 'content-type: application/json' \
        -d '{"user_name": "alice", "password": "pass"}' \
        http://server:8080/rest/login
        """,
        2,
    )
)

assert actual == expected, f"Expected {expected}, but got {actual}"

res = client.succeed("cat cookie.txt")
print(res)


# get recipes
recipes = json.loads(
    client.wait_until_succeeds(
        "curl --fail --silent -b cookie.txt http://server:8080/rest/recipes?select=title",
        2,
    )
)

expected_recipes = [
    {"title": "Cheese Cake"},
    {"title": "Fläskpannkaka i ugn"},
    {"title": "Omelett"},
    {"title": "Iskaffe med kondenserad mjölk och choklad"},
    {"title": "Rabarberlemonad"},
    {"title": "Boeuf bourguignon"},
    {"title": "Chokladkaka"},
]

assert len(recipes) == len(expected_recipes)
assert recipes == expected_recipes
