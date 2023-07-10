package org.acme.rest.json;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Set;

@Path("/fruits")
public class FruitResource {

    private Set<Fruit> fruits = Collections.newSetFromMap(Collections.synchronizedMap(new LinkedHashMap<>()));

    public FruitResource() {
        fruits.add(new Fruit("Apple", "Winter fruit"));
        fruits.add(new Fruit("Pineapple", "Tropical fruit"));
    }

    @GET
    public Set<Fruit> list() {
        return fruits;
    }
}
