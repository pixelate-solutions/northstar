import Fastify from 'fastify';
import { accountRoutes } from './routes/account';
import { billingRoutes } from './routes/billing';
import { healthRoutes } from './routes/health';
import { runRoutes } from './routes/runs';

const app = Fastify({ logger: true });

app.register(healthRoutes);
app.register(accountRoutes);
app.register(billingRoutes);
app.register(runRoutes);

const port = Number(process.env.PORT ?? 8080);
const host = '0.0.0.0';

app.listen({ port, host }, (err) => {
  if (err) {
    app.log.error(err);
    process.exit(1);
  }
});
