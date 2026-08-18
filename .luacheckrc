std = "luajit"

exclude_files = {}

files["**/*.lua"] = {
  unused = false,
  unused_args = false,
}

files["spec/**/*.lua"] = {
  std = "luajit+busted",
}

unused = true
unused_args = true
unused_secondaries = true
redefined = true