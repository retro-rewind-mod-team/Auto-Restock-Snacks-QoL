-- ============================================================
--  Retro Rewind - Auto Restock Snacks QoL
--  CONFIGURATION FILE
--
--  restockHours  = list of ingame hours that trigger a restock
--                  after the store opens (e.g. 18 = 6 PM)
--  deductCost    = true  → snack purchase costs are deducted
--                  false → restocking is free
--  restockCandy  = true  → candy dispensers are also refilled
-- ============================================================

return {

    Debug = false,

    restockHours = {
        { hour = 18 },
    },

    deductCost   = true,
    restockCandy = true,

}
