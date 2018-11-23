package hashiapp;

import java.util.HashMap;
import java.util.Map;

import spark.ModelAndView;
import spark.template.velocity.VelocityTemplateEngine;

import static spark.Spark.*;

public class Hello {

	public static void main(final String[] args) {
		staticFileLocation("/public");

		Map<String, Object> model = new HashMap<>();

		ProcessBuilder processBuilder = new ProcessBuilder();
		if (processBuilder.environment().get("NOMAD_ALLOC_NAME") != null) {
			model.put("server_id", processBuilder.environment().get("NOMAD_ALLOC_NAME"));
		} else {
			model.put("server_id", "dev_version");
		}

		if (processBuilder.environment().get("NOMAD_HOST_PORT_http") != null) {
			port(Integer.parseInt(processBuilder.environment().get("NOMAD_HOST_PORT_http")));
		} else {
			port(4567);
		}

		get("/", (req, res) -> new ModelAndView(model, "home.vm"), new VelocityTemplateEngine()); 
	}

}
