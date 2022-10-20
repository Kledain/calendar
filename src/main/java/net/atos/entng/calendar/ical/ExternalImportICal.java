package net.atos.entng.calendar.ical;

import fr.wseduc.mongodb.MongoDb;
import io.vertx.core.Future;
import io.vertx.core.Handler;
import io.vertx.core.Promise;
import io.vertx.core.eventbus.Message;;
import io.vertx.core.json.JsonObject;
import io.vertx.core.logging.Logger;
import io.vertx.core.logging.LoggerFactory;
import io.vertx.ext.web.client.WebClient;
import io.vertx.ext.web.client.WebClientOptions;
import net.atos.entng.calendar.core.constants.Field;
import net.atos.entng.calendar.services.EventServiceMongo;
import net.atos.entng.calendar.services.ServiceFactory;
import net.atos.entng.calendar.services.impl.EventServiceMongoImpl;
import org.entcore.common.neo4j.Neo4j;
import org.entcore.common.sql.Sql;
import org.entcore.common.user.UserInfos;
import org.entcore.common.user.UserUtils;
import org.vertx.java.busmods.BusModBase;


public class ExternalImportICal extends BusModBase implements Handler<Message<JsonObject>> {
    protected static final Logger log = LoggerFactory.getLogger(ExternalImportICal.class);
    private EventServiceMongo eventService;
    private WebClient webClient;
    private JsonObject calendar;
    private JsonObject requestInfo;
    private UserInfos user;


    @Override
    public void start() {
        super.start();
        WebClientOptions options = new WebClientOptions();
        options.setSsl(true);
        options.setTrustAll(true);
        ServiceFactory serviceFactory = new ServiceFactory(vertx, Neo4j.getInstance(), Sql.getInstance(),
                MongoDb.getInstance(), WebClient.create(vertx, options));
        this.eventService = new EventServiceMongoImpl(Field.CALENDAR, eb, serviceFactory);
        this.webClient = serviceFactory.webClient();
        eb.consumer(this.getClass().getName(), this);
    }

    @Override
    public void handle(Message<JsonObject> message) {
        String userId = message.body().getString(Field.USERID);
        UserUtils.getUserInfos(eb, userId, user -> {
            String action = message.body().getString(Field.ACTION, "");
            switch (action) {
                case Field.POST:
                    createEventsFromICal(message, user);
                    break;
                case Field.PUT:
                    //TODO MC-171
                    break;
                default:
                    break;
            }

        });
    }

    private void createEventsFromICal(Message<JsonObject> message, UserInfos user) {
        JsonObject results = new JsonObject();
        this.user = user;
        this.calendar = message.body().getJsonObject(Field.CALENDAR, new JsonObject());
        this.requestInfo = message.body().getJsonObject(Field.REQUEST, new JsonObject());

        fetchICalFromUrl(message.body().getJsonObject(Field.CALENDAR, new JsonObject()).getString(Field.ICSLINK, null))
                .compose(ical -> eventService.importIcal(calendar.getString(Field._ID), ical, user, requestInfo, Field.CALENDAREVENT))
                .onSuccess(message::reply)
                .onFailure(err -> {
                    String errMessage = String.format("[Calendar@%s::fetchICalFromUrl]:  " +
                                    "an error has occurred while creating external calendar events: %s",
                            this.getClass().getSimpleName(), err.getMessage());
                    log.error(errMessage);
                    message.reply(err);
                });
    }

    private Future<String> fetchICalFromUrl(String url) {
        Promise<String> promise = Promise.promise();

        this.webClient
                .getAbs(url)
                .send(result -> {
                    if (result.failed()) {
                        promise.fail(result.cause());
                    } else {
                        promise.complete(result.result().bodyAsString());
                    }
                });
        return promise.future();
    }

}
