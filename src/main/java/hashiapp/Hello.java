package hashiapp;

import java.util.HashMap;
import java.util.Map;
import java.util.List;

import java.sql.DriverManager;
import java.sql.Connection;
import java.sql.SQLException;

import com.bettercloud.vault.*;
import com.bettercloud.vault.response.LogicalResponse;

import spark.ModelAndView;
import spark.template.velocity.VelocityTemplateEngine;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static spark.Spark.*;

public class Hello {

	public static void main(final String[] args) {

		staticFileLocation("/public");

		ProcessBuilder processBuilder = new ProcessBuilder();

		// Set logging
		Logger log = LoggerFactory.getLogger(Hello.class);

		// Credentials and defaults
		String db_username = "hashiuser";
		String db_password = "hashipassword";

		String db_host = processBuilder.environment().get("DB_HOST");
		if (db_host == null) {
			db_host = "localhost";
		}

		String db_port = processBuilder.environment().get("DB_PORT");
		if (db_port == null) {
			db_port = "5432";
		}

		String db_name = processBuilder.environment().get("DB_NAME");
		if (db_name == null) {
			db_name = "hashiapp";
		}

		String vault_token = processBuilder.environment().get("VAULT_TOKEN");
		String vault_address = processBuilder.environment().get("VAULT_ADDRESS");
		if (vault_token == null && vault_address == null) {
			log.error("VAULT_TOKEN y/o VAULT_ADDRESS no configurados.");
		} else {
			try {
				final VaultConfig config = new VaultConfig().address(vault_address).token(vault_token).build();
				final Vault vault = new Vault(config);
				final LogicalResponse db_creds = vault.logical().read("database/creds/hashirole");
				db_username = db_creds.getData().get("username");
				db_password = db_creds.getData().get("password");
				log.info("VAULT: Nuevas credenciales '" + db_username + "'");
			}
			catch (VaultException v){
				log.error("Error al obtener credenciales de Vault");
				System.out.println(v);
			}
		}

		// Database connection
		Connection connection = null;
		try {
			connection = DriverManager.getConnection("jdbc:postgresql://" + db_host + ":" + db_port + "/" + db_name, db_username, db_password);
		} catch (SQLException e) {
			log.error("La conexión ha fallado!");
			e.printStackTrace();
			return;
		}

		if (connection != null) {
			log.info("Conectado a la base de datos!");
		} else {
			log.error("Conexión a la base de datos fallida.");
			return;
		}

		Map<String, Object> model = new HashMap<>();

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
		get("/version", (req, res) -> "v2.0");
		get("/health", (req, res) -> "OK");
	}

}
