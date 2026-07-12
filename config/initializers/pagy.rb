# Used to paginate the /sponsors/locations city directory, which is built
# from a plain sorted Ruby Array (Company.distinct_cities), not an
# ActiveRecord relation.
require "pagy/extras/array"

Pagy::DEFAULT[:limit] = 50
