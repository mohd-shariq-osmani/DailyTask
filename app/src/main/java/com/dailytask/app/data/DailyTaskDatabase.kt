package com.dailytask.app.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [Task::class, TaskCompletionHistory::class, TaskDailyLog::class],
    version = 3,
    exportSchema = false
)
abstract class DailyTaskDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao

    companion object {
        @Volatile
        private var INSTANCE: DailyTaskDatabase? = null

        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE tasks ADD COLUMN displayOrder INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE tasks ADD COLUMN colorHex TEXT NOT NULL DEFAULT '#8B5CF6'")
            }
        }

        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS `task_daily_log` (" +
                    "`date` TEXT NOT NULL, " +
                    "`taskId` INTEGER NOT NULL, " +
                    "`taskTitle` TEXT NOT NULL, " +
                    "`isCompleted` INTEGER NOT NULL, " +
                    "`colorHex` TEXT NOT NULL, " +
                    "PRIMARY KEY(`date`, `taskId`))"
                )
            }
        }

        fun getDatabase(context: Context): DailyTaskDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    DailyTaskDatabase::class.java,
                    "dailytask_database"
                )
                .addMigrations(MIGRATION_1_2, MIGRATION_2_3)
                .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
