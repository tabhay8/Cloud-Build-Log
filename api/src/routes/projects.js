"use strict";

const express = require("express");

function createProjectsRouter(db, logger) {
  const router = express.Router();

  router.get("/projects", async (req, res) => {
    const startedAt = Date.now();
    const limit = Math.min(Number.parseInt(req.query.limit, 10) || 50, 200);
    const tag = req.query.tag ? String(req.query.tag) : null;

    const statement = [
       "SELECT TOP (@limit)",
      "  Id AS id,",
      "  Title AS title,",
      "  Description AS description,",
      "  Tags AS tags,",
      "  Badge AS badge,",
      "  ImageUrl AS imageUrl,",
      "  Link AS link,",
      "  CreatedAt AS createdAt",
      "FROM dbo.Projects",
      tag ? "WHERE Tags LIKE @tag" : "",
      "ORDER BY CreatedAt DESC"
    ]
      .filter(Boolean)
      .join("\n");

    try {
      const result = await db.query(statement, (request) => {
        request.input("limit", db.sql.Int, limit);
        if (tag) request.input("tag", db.sql.NVarChar, "%" + tag + "%");
      });

      logger.info("projects query completed", {
        requestId: req.id,
        rows: result.recordset.length,
        durationMs: Date.now() - startedAt
      });

      res.json(result.recordset);
    } catch (error) {
      logger.error("projects query failed", {
        requestId: req.id,
        durationMs: Date.now() - startedAt,
        error: error.message
      });
      res.status(503).json({
        error: "projects_unavailable",
        message: "The projects data source is not reachable right now.",
        requestId: req.id
      });
    }
  });

  return router;
}

module.exports = { createProjectsRouter };
