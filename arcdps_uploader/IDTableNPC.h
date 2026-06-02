#pragma once
#include <string>
#include <map>
#include <filesystem>

struct NPCData {
    std::string name;
    std::string category;
};

class IDTableNPC {
public:
    static void load(const std::filesystem::path& json_path);
    static void save();
    static std::string getCategory(int boss_id);
    static std::string getName(int boss_id);
    static void addOrUpdate(int boss_id, const std::string& name);

private:
    static std::map<int, NPCData> npcs;
    static std::filesystem::path file_path;
};
