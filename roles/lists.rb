name "lists"
run_list [
  "recipe[scale_mailman]",
  "recipe[scale_phplist::cleanup]",
]
