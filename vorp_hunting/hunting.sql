
-- ----------------------------
-- Add huntingxp to character
-- Insert items into item datadase.
-- ----------------------------
ALTER TABLE `character`
ADD COLUMN huntingxp INT(11) DEFAULT 0;

INSERT INTO items (item, label, `limit`, can_remove, type, usable, groupId, metadata, `desc`) VALUES 
('consumable_predator_bait', 'Consumable Predator Bait', 10, 1, 'item_standard', 1, 1, '{}', 'A bait used to attract predators.'),
('consumable_potent_predator_bait', 'Consumable Potent Predator Bait', 5, 1, 'item_standard', 1, 1, '{}', 'A potent bait used to attract powerful predators.'),
('consumable_potent_herbivore_bait', 'Consumable Potent Herbivore Bait', 5, 1, 'item_standard', 1, 1, '{}', 'A potent bait used to attract powerful herbivores.'),
('consumable_herbivore_bait', 'Consumable Herbivore Bait', 10, 1, 'item_standard', 1, 1, '{}', 'A bait used to attract herbivores.'),
('consumable_legendary_bait', 'Consumable Legendary Animal Bait', 3, 1, 'item_standard', 1, 1, '{}', 'A bait used to attract legendary animals.');