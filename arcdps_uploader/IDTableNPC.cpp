#include "IDTableNPC.h"
#include "DefaultIDTableNPC.h"
#include "loguru.hpp"
#include <fstream>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

std::map<int, NPCData> IDTableNPC::npcs;
std::filesystem::path IDTableNPC::file_path;

void IDTableNPC::load(const std::filesystem::path& json_path) {
    file_path = json_path;
    
    if (!std::filesystem::exists(file_path)) {
        LOG_F(INFO, "id_table_npc.json not found, creating default.");
        std::ofstream out(file_path);
        out << DEFAULT_IDTABLENPC_JSON;
        out.close();
    }
    
    try {
        std::ifstream in(file_path);
        json j;
        in >> j;
        for (auto& [key, value] : j.items()) {
            int id = std::stoi(key);
            npcs[id] = { value.value("name", "Unknown"), value.value("category", "UNKNOWN") };
        }
        LOG_F(INFO, "Loaded %zu npcs from id_table_npc.json", npcs.size());
    } catch (std::exception& e) {
        LOG_F(ERROR, "Failed to load id_table_npc.json: %s", e.what());
    }
}

void IDTableNPC::save() {
    try {
        json j;
        for (auto& [id, data] : npcs) {
            j[std::to_string(id)] = { {"name", data.name}, {"category", data.category} };
        }
        std::ofstream out(file_path);
        out << j.dump(4);
        out.close();
    } catch (std::exception& e) {
        LOG_F(ERROR, "Failed to save id_table_npc.json: %s", e.what());
    }
}

std::string IDTableNPC::getCategory(int boss_id) {
    if (npcs.count(boss_id)) {
        return npcs[boss_id].category;
    }
    return "UNKNOWN";
}

std::string IDTableNPC::getName(int boss_id) {
    if (npcs.count(boss_id)) {
        return npcs[boss_id].name;
    }
    return "Unknown";
}

void IDTableNPC::addOrUpdate(int boss_id, const std::string& name) {
    if (boss_id == 0) return;
    
    bool changed = false;
    if (npcs.count(boss_id) == 0) {
        npcs[boss_id] = { name, "UNKNOWN" };
        changed = true;
        LOG_F(INFO, "Added new boss %d: %s", boss_id, name.c_str());
    } else {
        if (!name.empty() && npcs[boss_id].name != name) {
            LOG_F(INFO, "Updated boss name %d from %s to %s", boss_id, npcs[boss_id].name.c_str(), name.c_str());
            npcs[boss_id].name = name;
            changed = true;
        }
    }
    
    if (changed) save();
}
